import { initializeApp, FirebaseApp } from 'firebase/app';
import { getAuth, Auth } from 'firebase/auth';
import { getDatabase, Database } from 'firebase/database';
import { getStorage, FirebaseStorage } from 'firebase/storage';

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  databaseURL: process.env.NEXT_PUBLIC_FIREBASE_DATABASE_URL,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

// This client-only app is statically rendered during `next build`. Deferring
// Firebase service construction on the server keeps the build independent of
// deployment secrets while the browser receives its Vercel environment values.
const isBrowser = typeof window !== 'undefined';
const app: FirebaseApp | null = isBrowser ? initializeApp(firebaseConfig) : null;
export const auth: Auth = (isBrowser ? getAuth(app!) : null) as Auth;
export const database: Database = (isBrowser ? getDatabase(app!) : null) as Database;
export const storage: FirebaseStorage = (isBrowser ? getStorage(app!) : null) as FirebaseStorage;
