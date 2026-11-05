const {HttpsError} = require('firebase-functions/v2/https');

async function deleteAccount(actorUid, uid, {db, auth, timestamp}) {
  if (!actorUid) throw new HttpsError('unauthenticated', 'Inicia sesión.');
  if (typeof uid !== 'string' || !uid || uid.length > 128 || uid.includes('/')) {
    throw new HttpsError('invalid-argument', 'Selecciona una cuenta válida.');
  }
  if (uid === actorUid) throw new HttpsError('failed-precondition', 'No puedes eliminar tu propia cuenta.');
  const profile = db.doc(`users/${uid}`);
  const deletion = db.doc(`_user_deletions/${uid}`);
  // A durable marker blocks profile recreation by still-valid tokens. Disable
  // access before calling Auth; a failure leaves a safe, retryable operation.
  await db.runTransaction(async tx => {
    const actor = await tx.get(db.doc(`users/${actorUid}`));
    const target = await tx.get(profile);
    const previous = await tx.get(deletion);
    if (actor.data()?.role !== 'admin' || actor.data()?.active !== true) {
      throw new HttpsError('permission-denied', 'Se requiere un administrador activo.');
    }
    if (!target.exists && !previous.exists) throw new HttpsError('not-found', 'La cuenta ya no existe.');
    if (!previous.exists) {
      tx.set(deletion, {actorUid, actorName: actor.data().name, targetName: target.data().name, startedAt: timestamp()});
    }
    if (target.exists) tx.update(profile, {active: false, updatedAt: timestamp()});
  });
  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw new HttpsError('unavailable', 'La cuenta quedó desactivada. Reintenta eliminarla para completar el proceso.');
    }
  }
  // Only private alerts are removed. Shared devices/scenes/energy and historical
  // activity remain available to the household.
  while (true) {
    const alerts = await db.collection('alerts').where('userId', '==', uid).limit(200).get();
    if (alerts.empty) break;
    const batch = db.batch();
    for (const alert of alerts.docs) batch.delete(alert.ref);
    await batch.commit();
  }
  await db.runTransaction(async tx => {
    const marker = await tx.get(deletion);
    if (marker.data()?.completedAt) return;
    tx.delete(profile);
    tx.update(deletion, {completedAt: timestamp()});
    tx.set(db.doc(`activity/delete_user_${uid}`), {
      userId: marker.data().actorUid, action: 'admin_delete', entityType: 'users', entityId: uid,
      description: `Eliminó usuario: ${marker.data().targetName}`,
      createdAt: timestamp(),
    });
  });
  return {deleted: true};
}
module.exports = {deleteAccount};
