const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {onCall} = require('firebase-functions/v2/https');
const {deleteAccount} = require('./delete_account.cjs');
initializeApp();

exports.deleteUserAccount = onCall({region: 'us-central1', maxInstances: 1, timeoutSeconds: 120}, request =>
  deleteAccount(request.auth?.uid, request.data?.uid, {
    db: getFirestore(), auth: getAuth(), timestamp: () => FieldValue.serverTimestamp(),
  }));
