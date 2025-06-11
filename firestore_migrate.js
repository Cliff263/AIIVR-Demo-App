const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

async function migrateUsers() {
  const users = await db.collection('users').get();
  for (const doc of users.docs) {
    const data = doc.data();
    const updates = {};
    if (!data.role) updates.role = 'agent'; // Default, or prompt for correct role
    if (updates.role === 'agent' && typeof data.isOnline === 'undefined') updates.isOnline = false;
    if (Object.keys(updates).length > 0) {
      await doc.ref.update(updates);
      console.log(`Updated user ${doc.id}:`, updates);
    }
  }
}

async function migrateQueries() {
  const queries = await db.collection('queries').get();
  for (const doc of queries.docs) {
    const data = doc.data();
    const updates = {};
    if (!data.status) updates.status = 'pending';
    if (!('assignedTo' in data)) updates.assignedTo = null;
    if (!('assignedBy' in data)) updates.assignedBy = null;
    if (!('assignedAt' in data)) updates.assignedAt = null;
    if (!('resolvedAt' in data)) updates.resolvedAt = null;
    if (Object.keys(updates).length > 0) {
      await doc.ref.update(updates);
      console.log(`Updated query ${doc.id}:`, updates);
    }
  }
}

async function migrateChats() {
  const chats = await db.collection('chats').get();
  for (const doc of chats.docs) {
    const data = doc.data();
    if (!data.participants) {
      await doc.ref.update({ participants: {} });
      console.log(`Updated chat ${doc.id}: added empty participants`);
    }
  }
}

async function migrateMessages() {
  const messages = await db.collection('messages').get();
  for (const doc of messages.docs) {
    const data = doc.data();
    if (!data.status) {
      await doc.ref.update({ status: 'sent' });
      console.log(`Updated message ${doc.id}: set status to sent`);
    }
  }
}

async function runMigrations() {
  console.log('Migrating users...');
  await migrateUsers();
  console.log('Migrating queries...');
  await migrateQueries();
  console.log('Migrating chats...');
  await migrateChats();
  console.log('Migrating messages...');
  await migrateMessages();
  console.log('All migrations complete!');
}

runMigrations().catch(console.error);