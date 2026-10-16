import { after, before, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc, Timestamp } from 'firebase/firestore';

const projectId = 'demo-leaguedex';
let environment;
const database = (uid = 'alice', claims = {}) => uid === null
  ? environment.unauthenticatedContext().firestore()
  : environment.authenticatedContext(uid, claims).firestore();
const favorite = () => ({ championID: 'Ahri', selected: true, updatedAt: serverTimestamp() });

before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Run npm run test:rules with FIRESTORE_EMULATOR_HOST set.');
  }
  environment = await initializeTestEnvironment({
    projectId, firestore: { rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8') }
  });
});
beforeEach(async () => { await environment.clearFirestore(); });
after(async () => { await environment?.cleanup(); });

test('Favorites belong to their signed-in account', async () => {
  const own = doc(database(), 'users/alice/favorites/Ahri');
  await assertSucceeds(setDoc(own, favorite()));
  await assertSucceeds(getDoc(own));
  await assertSucceeds(getDocs(collection(database(), 'users/alice/favorites')));
  await assertFails(getDoc(doc(database('bob'), own.path)));
  await assertFails(getDoc(doc(database(null), own.path)));
  await assertFails(getDoc(doc(database('staff', { admin: true }), own.path)));
  await assertFails(setDoc(doc(database('bob'), own.path), favorite()));
});

test('Favorite writes validate shape and keep deletion tombstones', async () => {
  const own = doc(database(), 'users/alice/favorites/Ahri');
  await assertSucceeds(setDoc(own, favorite()));
  await assertSucceeds(updateDoc(own, { selected: false, updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(own));
  for (const invalid of [
    { championID: 'Lux', selected: true, updatedAt: serverTimestamp() },
    { championID: 'Ahri', selected: 'true', updatedAt: serverTimestamp() },
    { championID: 'Ahri', selected: true, updatedAt: Timestamp.fromMillis(0) },
    { ...favorite(), admin: true }
  ]) {
    await assertFails(setDoc(own, invalid));
  }
});

test('Catalogs are readable when signed in and writable only by admin', async () => {
  for (const path of ['champions/Ahri', 'items/1001', 'venues/bar']) {
    await assertFails(setDoc(doc(database(), path), { name: 'client' }));
    await assertFails(getDoc(doc(database(null), path)));
    await assertSucceeds(setDoc(doc(database('staff', { admin: true }), path), { name: 'trusted' }));
    await assertSucceeds(getDoc(doc(database(), path)));
  }
});

test('Removed features and unknown data paths are inaccessible', async () => {
  for (const path of [
    'users/alice/builds/one',
    'users/alice/quizRuns/one',
    'users/alice/comparisons/one',
    'users/alice/venueProposals/today',
    'users/alice/venueReports/report',
    'unknown/example'
  ]) {
    await assertFails(getDoc(doc(database(), path)));
    await assertFails(setDoc(doc(database(), path), { name: 'unexpected' }));
  }
});
