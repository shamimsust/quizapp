import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
admin.initializeApp();

export const onAttemptSubmit = functions.database.ref('/attempts/{attemptId}/status').onWrite(async (change, context) => {
  const status = change.after.val();
  if (status !== 'submitted' && status !== 'submitted_timeout') return null;
  const attemptId = context.params.attemptId;
  const db = admin.database();
  const attemptSnap = await db.ref(`/attempts/${attemptId}`).once('value');
  const attempt = attemptSnap.val();
  const examId = attempt.examId;
  const qSnap = await db.ref(`/examQuestions/${examId}`).once('value');
  const qs = qSnap.val() || {};
  const ansSnap = await db.ref(`/attemptAnswers/${attemptId}`).once('value');
  const answers = ansSnap.val() || {};

  let total = 0;
  const perQuestion = {};

  for (const [qid, q] of Object.entries(qs)) {
    if (q.type && q.type.startsWith('mcq')) {
      const correct = new Set(q.correctOptions || []);
      const selected = new Set(((answers[qid] || {}).selected) || []);
      const ok = correct.size === selected.size && [...correct].every(c => selected.has(c));
      const marks = q.marks || 1;
      const score = ok ? marks : 0;
      perQuestion[qid] = score;
      total += score;
    }
  }

  await db.ref(`/results/${attemptId}`).update({
    status: 'awaiting_manual',
    auto: { total, perQuestion },
    updatedAt: admin.database.ServerValue.TIMESTAMP,
  });

  return null;
});

/**
 * Shared resolution logic for "the user typed either a token or a raw
 * examId" — matches the fallback behavior CandidateInfoScreen used to do
 * client-side, but now also enforces the published-status check that was
 * previously missing from that code path.
 *
 * Returns either:
 *   { token, examId, examTitle, durationMs }
 * or:
 *   { error: '<https.HttpsError code>', message: '<user-facing message>' }
 */
async function resolveExamEntry(db, rawInput) {
  const input = (rawInput ?? '').toString().trim();
  if (!input) {
    return { error: 'invalid-argument', message: 'No quiz ID or token provided.' };
  }
  if (/[.#$[\]/]/.test(input)) {
    return { error: 'invalid-argument', message: 'Input contains invalid characters.' };
  }

  let token = null;
  let examId = input;

  const tokenSnap = await db.ref(`examTokens/${input}`).once('value');
  if (tokenSnap.exists()) {
    token = input;
    const tokenData = tokenSnap.val() || {};
    examId = tokenData.examId ? String(tokenData.examId) : null;
    if (!examId) {
      return { error: 'failed-precondition', message: 'This token points to an invalid quiz.' };
    }
  }
  // else: assume `input` is a direct examId, same fallback the old client code used.

  const examSnap = await db.ref(`exams/${examId}`).once('value');
  if (!examSnap.exists()) {
    return { error: 'not-found', message: 'Quiz settings not found. Please contact support.' };
  }
  const examData = examSnap.val() || {};
  const status = examData.status ? String(examData.status) : 'draft';
  if (status !== 'published') {
    return {
      error: 'failed-precondition',
      message: 'This exam is currently in DRAFT mode and not accepting entries.',
    };
  }

  return {
    token,
    examId,
    examTitle: examData.title ? String(examData.title) : 'Untitled Exam',
    durationMs: examData.durationMs || 3600000,
  };
}

/**
 * Read-only preview used by CandidateInfoScreen before registration, to
 * show the exam title and confirm it's actually joinable — without the
 * client needing direct read access to examTokens or exams.
 */
export const resolveExamPreview = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be signed in.');
  }
  const db = admin.database();
  const result = await resolveExamEntry(db, data?.input);
  if (result.error) {
    throw new functions.https.HttpsError(result.error, result.message);
  }
  return { examId: result.examId, examTitle: result.examTitle };
});

/**
 * Creates a new attempt. Replaces CandidateInfoScreen's previous
 * check-then-create flow with a single atomic operation:
 *   - re-resolves + re-validates the token/examId/published status
 *   - validates name/email server-side (never trust client validation alone)
 *   - uses a transaction on a dedicated index node (attemptIndex/{uid_examId})
 *     so two near-simultaneous calls can't both create an attempt for the
 *     same (uid, examId) pair — closing the old race condition
 *   - computes endTime from the Cloud Function's own server clock, not the
 *     candidate's device clock, closing the clock-skew exam-time exploit
 */
export const startExamAttempt = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be signed in.');
  }
  const uid = context.auth.uid;

  const name = (data?.name ?? '').toString().trim();
  const email = (data?.email ?? '').toString().trim();
  if (!name) {
    throw new functions.https.HttpsError('invalid-argument', 'Name is required.');
  }
  if (!/^[a-zA-Z0-9.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z]+/.test(email)) {
    throw new functions.https.HttpsError('invalid-argument', 'A valid email is required.');
  }

  const db = admin.database();
  const result = await resolveExamEntry(db, data?.input);
  if (result.error) {
    throw new functions.https.HttpsError(result.error, result.message);
  }
  const { token, examId, examTitle, durationMs } = result;

  const indexKey = `${uid}_${examId}`;
  const attemptRef = db.ref('attempts').push();
  const attemptId = attemptRef.key;

  const txResult = await db.ref(`attemptIndex/${indexKey}`).transaction((current) => {
    if (current) return; // abort — another call already holds this slot
    return attemptId;
  });

  if (!txResult.committed) {
    throw new functions.https.HttpsError(
      'already-exists',
      'You have already started or submitted an attempt for this exam.'
    );
  }

  const now = Date.now(); // Cloud Functions run server-side — this is trustworthy, unlike a device clock.

  await attemptRef.set({
    examId,
    examTitle,
    userId: uid,
    userId_examId: indexKey,
    candidate: { name, email },
    status: 'in_progress',
    startTime: admin.database.ServerValue.TIMESTAMP,
    endTime: now + durationMs,
    createdFromToken: token,
  });

  return { attemptId };
});

/**
 * Validates an exam token entirely server-side using the Admin SDK, which
 * bypasses Realtime Database security rules. Used by TokenLandingScreen,
 * which only ever supplies a real token (never a raw examId), so this
 * stays separate from resolveExamEntry's token-or-id fallback above.
 */
export const redeemExamToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be signed in to redeem a token.'
    );
  }

  const token = (data?.token ?? '').toString().trim();
  if (!token) {
    throw new functions.https.HttpsError('invalid-argument', 'Token is required.');
  }
  if (/[.#$[\]/]/.test(token)) {
    throw new functions.https.HttpsError('invalid-argument', 'Token contains invalid characters.');
  }

  const db = admin.database();

  const tokenSnap = await db.ref(`examTokens/${token}`).once('value');
  if (!tokenSnap.exists()) {
    throw new functions.https.HttpsError('not-found', 'Invalid token. Please check the code.');
  }
  const tokenData = tokenSnap.val() || {};
  const examId = tokenData.examId ? String(tokenData.examId) : null;
  if (!examId) {
    throw new functions.https.HttpsError('failed-precondition', 'This token points to an invalid quiz.');
  }

  const examSnap = await db.ref(`exams/${examId}`).once('value');
  if (!examSnap.exists()) {
    throw new functions.https.HttpsError('not-found', 'The associated exam has been removed.');
  }
  const examData = examSnap.val() || {};
  const status = examData.status ? String(examData.status) : 'draft';
  if (status !== 'published') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'This exam is currently in DRAFT mode and not accepting entries.'
    );
  }

  const uid = context.auth.uid;
  const dupSnap = await db
    .ref('attempts')
    .orderByChild('userId_examId')
    .equalTo(`${uid}_${examId}`)
    .once('value');

  if (dupSnap.exists()) {
    throw new functions.https.HttpsError(
      'already-exists',
      'You have already started or submitted an attempt for this exam.'
    );
  }

  return {
    examId,
    examTitle: examData.title ? String(examData.title) : 'Untitled Exam',
  };
});