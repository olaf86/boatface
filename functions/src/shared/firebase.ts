import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";

initializeApp();

export const db = getFirestore();
export const auth = getAuth();
export const region = "asia-northeast2";
export const appHttpOptions = {region, invoker: "public"} as const;
