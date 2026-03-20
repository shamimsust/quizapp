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
