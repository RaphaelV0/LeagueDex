import { after, before, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import {
  assertFails, assertSucceeds, initializeTestEnvironment
} from '@firebase/rules-unit-testing';
import {
  collection, collectionGroup, deleteDoc, doc, getDoc, getDocs,
  serverTimestamp, setDoc, Timestamp, updateDoc
} from 'firebase/firestore';

// This project ID and the CLI script deliberately target emulators only.
const projectId = 'demo-leaguedex';
let environment;
const database = (uid = 'alice', claims = {}) => uid === null
  ? environment.unauthenticatedContext().firestore()
  : environment.authenticatedContext(uid, claims).firestore();
const favorite = (championID = 'Ahri') => ({ championID, selected: true, updatedAt: serverTimestamp() });
const build = (overrides = {}) => ({
  name: 'Mid AP', championID: 'Ahri', itemIDs: ['1001', '3089'], revision: 1, mutationID: 'operation-1',
  createdAt: serverTimestamp(), updatedAt: serverTimestamp(), deleted: false, ...overrides
});
const comparison = (overrides = {}) => ({
  leftID: 'Ahri', rightID: 'Lux', level: 18, updatedAt: serverTimestamp(), ...overrides
});
const quiz = (overrides = {}) => ({
  category: 'champion', difficulty: 'normal', score: 200, correct: 2, total: 3,
  completedAt: serverTimestamp(), dayKey: '', ...overrides
});

before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Run npm run test:rules: FIRESTORE_EMULATOR_HOST is required.');
  }
  environment = await initializeTestEnvironment({
    projectId, firestore: { rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8') }
  });
});
beforeEach(async () => { await environment.clearFirestore(); });
after(async () => { await environment?.cleanup(); });

test('private collections permit their owner and deny another user, admin, and unauthenticated requests', async () => {
  const alice = database();
  const writes = [
    ['favorites/Ahri', favorite()], ['builds/one', build()],
    ['comparisons/one', comparison()], ['quizRuns/one', quiz()]
  ];
  for (const [path, data] of writes) {
    await assertSucceeds(setDoc(doc(alice, `users/alice/${path}`), data));
    await assertSucceeds(getDoc(doc(alice, `users/alice/${path}`)));
    const collectionName = path.split('/')[0];
    await assertSucceeds(getDocs(collection(alice, `users/alice/${collectionName}`)));
    for (const other of [database('bob'), database(null), database('staff', { admin: true })]) {
      await assertFails(getDoc(doc(other, `users/alice/${path}`)));
      await assertFails(getDocs(collection(other, `users/alice/${collectionName}`)));
      await assertFails(setDoc(doc(other, `users/alice/${path}`), data));
      await assertFails(deleteDoc(doc(other, `users/alice/${path}`)));
    }
  }
});

test('new private writes, unknown paths, and parent documents cannot bypass uid ownership', async () => {
  const alice = database();
  const unauthenticated = database(null);
  for (const [path, data] of [
    ['favorites/Ahri', favorite()], ['builds/one', build()],
    ['comparisons/one', comparison()], ['quizRuns/one', quiz()]
  ]) {
    await assertFails(setDoc(doc(alice, `users/bob/${path}`), data));
    await assertFails(setDoc(doc(unauthenticated, `users/alice/${path}`), data));
  }
  for (const path of ['users/alice', 'users/alice/secret/one', 'users/alice/builds/one/nested/two', 'unknown/one']) {
    await assertFails(setDoc(doc(alice, path), { admin: true }));
    await assertFails(getDoc(doc(alice, path)));
  }
  await assertFails(getDocs(collectionGroup(alice, 'favorites')));
});

test('favorites validate the document ID, shape and server time; deselections remain tombstones', async () => {
  const reference = doc(database(), 'users/alice/favorites/Ahri');
  await assertSucceeds(setDoc(reference, favorite()));
  await assertSucceeds(updateDoc(reference, { selected: false, updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(reference));
  for (const invalid of [
    { ...favorite(), championID: 'Lux' }, { ...favorite(), selected: 'true' },
    { ...favorite(), admin: true }, { championID: 'Ahri', selected: true },
    { ...favorite(), updatedAt: Timestamp.fromMillis(0) }
  ]) { await assertFails(setDoc(reference, invalid)); }
});

test('builds accept zero through six string item IDs and reject oversized or malformed data', async () => {
  const alice = database();
  await assertSucceeds(setDoc(doc(alice, 'users/alice/builds/empty'), build({ itemIDs: [] })));
  await assertSucceeds(setDoc(doc(alice, 'users/alice/builds/full'), build({ itemIDs: ['1', '2', '3', '4', '5', '6'] })));
  for (const [index, invalid] of [
    { name: '' }, { name: 'a'.repeat(81) }, { championID: '' }, { championID: 1 },
    { itemIDs: ['1', '2', '3', '4', '5', '6', '7'] }, { itemIDs: { 0: '1001' } },
    { itemIDs: ['1001', 3089] }, { itemIDs: ['1001', ''] }, { itemIDs: ['1', '2', '3', '4', '5', false] },
    { revision: 0 }, { revision: 2 }, { revision: 1.5 }, { mutationID: '' }, { mutationID: 1 }, { deleted: 'false' },
    { createdAt: Timestamp.fromMillis(0) }, { updatedAt: Timestamp.fromMillis(0) }, { unexpected: true }
  ].entries()) {
    await assertFails(setDoc(doc(alice, `users/alice/builds/invalid-${index}`), build(invalid)));
  }
});

test('build revisions reject stale writes, preserve creation time and require deletion tombstones', async () => {
  const reference = doc(database(), 'users/alice/builds/one');
  await assertSucceeds(setDoc(reference, build()));
  await assertFails(updateDoc(reference, { name: 'Reused operation', revision: 2, updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(reference, { name: 'Updated', revision: 2, mutationID: 'operation-2', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(reference, { name: 'Stale', revision: 2, mutationID: 'operation-3', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(reference, { revision: 4, mutationID: 'operation-3', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(reference, { revision: 3, mutationID: 'operation-3', createdAt: Timestamp.fromMillis(0), updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(reference));
  await assertSucceeds(updateDoc(reference, { revision: 3, mutationID: 'operation-3', deleted: true, updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(reference, { revision: 3, mutationID: 'operation-4', deleted: false, updatedAt: serverTimestamp() }));
});

test('comparisons validate level and distinct champions; only their owner can delete them', async () => {
  const reference = doc(database(), 'users/alice/comparisons/one');
  await assertSucceeds(setDoc(reference, comparison({ level: 1 })));
  await assertSucceeds(setDoc(reference, comparison({ level: 18 })));
  for (const invalid of [
    { level: 0 }, { level: 19 }, { level: 1.5 }, { leftID: '' }, { rightID: 'Ahri' },
    { rightID: 7 }, { updatedAt: Timestamp.fromMillis(0) }, { unexpected: true }
  ]) { await assertFails(setDoc(reference, comparison(invalid))); }
  await assertFails(deleteDoc(doc(database('bob'), reference.path)));
  await assertSucceeds(deleteDoc(reference));
});

test('quiz runs validate score arithmetic and cannot be rewritten or deleted', async () => {
  const alice = database();
  const reference = doc(alice, 'users/alice/quizRuns/one');
  await assertSucceeds(setDoc(reference, quiz()));
  await assertFails(setDoc(reference, quiz({ correct: 3, score: 300 })));
  await assertFails(deleteDoc(reference));
  for (const [index, invalid] of [
    { total: 0 }, { total: 101 }, { total: 2.5 }, { correct: -1 }, { correct: 4 },
    { score: 201 }, { score: 2.5 }, { correct: 1.5, score: 150 }, { category: '' },
    { difficulty: 8 }, { completedAt: Timestamp.fromMillis(0) }, { dayKey: '2026-10-15' }, { unexpected: true }
  ].entries()) {
    await assertFails(setDoc(doc(alice, `users/alice/quizRuns/invalid-${index}`), quiz(invalid)));
  }
});

test('daily challenge IDs enforce one immutable result per owner and day', async () => {
  const alice = database();
  const reference = doc(alice, 'users/alice/quizRuns/daily-2026-10-15');
  await assertSucceeds(setDoc(reference, quiz({ dayKey: '2026-10-15' })));
  await assertFails(setDoc(reference, quiz({ dayKey: '2026-10-15' })));
  await assertFails(setDoc(doc(alice, 'users/alice/quizRuns/alternate'), quiz({ dayKey: '2026-10-15' })));
  await assertFails(setDoc(doc(alice, 'users/alice/quizRuns/daily-2026-10-16'), quiz()));
  for (const key of ['2026-13-15', '2026-10-00', 'yesterday']) {
    await assertFails(setDoc(doc(alice, `users/alice/quizRuns/daily-${key}`), quiz({ dayKey: key })));
  }
  await assertSucceeds(setDoc(doc(database('bob'), reference.path.replace('alice', 'bob')), quiz({ dayKey: '2026-10-15' })));
});

test('catalog reads require authentication; trusted admin claims alone permit catalog writes', async () => {
  for (const path of ['champions/Ahri', 'items/1001', 'venues/legacy']) {
    await assertFails(setDoc(doc(database(), path), { name: 'Unauthorized' }));
    await assertFails(setDoc(doc(database(null), path), { name: 'Unauthorized' }));
    await assertFails(setDoc(doc(database('bob', { admin: 'true' }), path), { name: 'Unauthorized' }));
    await assertSucceeds(setDoc(doc(database('staff', { admin: true }), path), { name: 'Catalog' }));
    await assertSucceeds(getDoc(doc(database(), path)));
    await assertFails(getDoc(doc(database(null), path)));
  }
});
