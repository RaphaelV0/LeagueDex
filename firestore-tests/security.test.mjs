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

test('Champion and item catalogs stay admin-only for writes', async () => {
  for (const path of ['champions/Ahri', 'items/1001']) {
    await assertFails(setDoc(doc(database(), path), { name: 'client' }));
    await assertFails(getDoc(doc(database(null), path)));
    await assertSucceeds(setDoc(doc(database('staff', { admin: true }), path), { name: 'trusted' }));
    await assertSucceeds(getDoc(doc(database(), path)));
  }
});

const newVenue = (overrides = {}) => ({
  name: 'Bar gaming',
  address: '12 rue Exemple, Lille',
  latitude: 50.63,
  longitude: 3.06,
  type: 'Bar E-sport',
  authorUID: 'alice',
  createdAt: serverTimestamp(),
  openingHours: '18h–23h',
  phone: '',
  website: '',
  details: '',
  ...overrides
});

test('Signed-in users can add public places visible to other accounts', async () => {
  const venue = doc(database(), 'venues/new-bar');
  await assertSucceeds(setDoc(venue, newVenue()));
  await assertSucceeds(getDoc(doc(database('bob'), venue.path)));
  await assertFails(getDoc(doc(database(null), venue.path)));
  await assertFails(updateDoc(venue, { name: 'Hacked' }));
  await assertFails(deleteDoc(venue));
  await assertFails(updateDoc(doc(database('bob'), venue.path), { name: 'Other change' }));
  await assertFails(setDoc(doc(database('bob'), venue.path), newVenue({ authorUID: 'bob' })));
  await assertSucceeds(updateDoc(doc(database('staff', { admin: true }), venue.path), { name: 'Corrected' }));
});

test('New venues reject unauthenticated and malformed submissions', async () => {
  await assertFails(setDoc(doc(database(null), 'venues/anon'), newVenue()));
  await assertFails(setDoc(doc(database('bob'), 'venues/bob-as-alice'), newVenue()));
  for (const [i, fields] of [
    { authorUID: 'bob' }, { name: '' }, { name: 'x'.repeat(121) },
    { address: '' }, { address: 'x'.repeat(251) },
    { latitude: -91 }, { latitude: '50.6' }, { longitude: 181 },
    { type: 'Incorrect' }, { openingHours: 'x'.repeat(501) },
    { phone: 123 }, { website: 'x'.repeat(301) },
    { details: 'x'.repeat(1501) },
    { createdAt: Timestamp.fromMillis(0) }, { extra: true }
  ].entries()) {
    await assertFails(setDoc(doc(database(), 'venues/invalid-' + i), newVenue(fields)));
  }
  await assertFails(setDoc(doc(database(), 'venues/no-coordinate'), {
    name: 'No position', address: 'Lille', type: 'Bar E-sport',
    authorUID: 'alice', createdAt: serverTimestamp()
  }));
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
