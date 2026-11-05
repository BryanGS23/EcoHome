const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8085') throw new Error('Solo usar el emulador local.');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {deleteAccount} = require('../delete_account.cjs');
const app = initializeApp({projectId: 'demo-ecohome-delete-tests'}, 'delete-tests');
const db = getFirestore(app);
let authCalls = 0;
const auth = {async deleteUser() { authCalls++; }};
const services = {db, auth, timestamp: () => FieldValue.serverTimestamp()};
before(async () => {
  await db.doc('users/delete-admin').set({name:'Administrador',role:'admin',active:true});
  await db.doc('users/delete-regular').set({name:'Regular',role:'user',active:true});
  await db.doc('users/delete-inactive').set({name:'Inactivo',role:'admin',active:false});
});
after(() => deleteApp(app));

test('sin sesión, user, admin inactivo y autoeliminación no alcanzan Auth', async () => {
  for (const [actor,target,code] of [[null,'victim','unauthenticated'],['delete-regular','victim','permission-denied'],['delete-inactive','victim','permission-denied'],['delete-admin','delete-admin','failed-precondition'],['delete-admin','a/b','invalid-argument']]) {
    await assert.rejects(deleteAccount(actor,target,services), e => e.code === code);
  }
  assert.equal(authCalls,0);
});
test('elimina perfil y alertas propias, conserva datos compartidos y registra una sola actividad', async () => {
  await db.doc('users/delete-victim').set({name:'Víctima de prueba',role:'user',active:true});
  await db.doc('alerts/delete-own').set({userId:'delete-victim'});
  await db.doc('alerts/delete-other').set({userId:'delete-regular'});
  await db.doc('devices/delete-shared').set({name:'Compartido'});
  await deleteAccount('delete-admin','delete-victim',services);
  assert.equal((await db.doc('users/delete-victim').get()).exists,false);
  assert.equal((await db.doc('alerts/delete-own').get()).exists,false);
  assert.equal((await db.doc('alerts/delete-other').get()).exists,true);
  assert.equal((await db.doc('devices/delete-shared').get()).exists,true);
  const activity = await db.doc('activity/delete_user_delete-victim').get();
  assert.equal(activity.data().userId,'delete-admin');
  const date = activity.data().createdAt.toMillis();
  await deleteAccount('delete-admin','delete-victim',{...services,auth:{async deleteUser(){throw {code:'auth/user-not-found'};}}});
  assert.equal((await db.doc('activity/delete_user_delete-victim').get()).data().createdAt.toMillis(),date);
});
test('fallo de Auth deja la cuenta bloqueada y un reintento completa la eliminación', async () => {
  await db.doc('users/delete-retry').set({name:'Reintento',role:'user',active:true});
  await assert.rejects(deleteAccount('delete-admin','delete-retry',{...services,auth:{async deleteUser(){throw new Error('Sin conexión');}}}), e => e.code === 'unavailable');
  assert.equal((await db.doc('users/delete-retry').get()).data().active,false);
  assert.equal((await db.doc('_user_deletions/delete-retry').get()).exists,true);
  await deleteAccount('delete-admin','delete-retry',services);
  assert.equal((await db.doc('users/delete-retry').get()).exists,false);
});
