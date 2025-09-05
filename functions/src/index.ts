import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

// Interface untuk tipe data yang dikirim dari Flutter
interface CreatePegawaiData {
  nama: string;
  email: string;
  password: string;
  organisasi: string;
  kodeOrganisasi: string;
}

interface UpdatePegawaiData {
  uid: string;
  newEmail: string;
  newPassword?: string;
}

interface DeletePegawaiData {
  uid: string;
}

// Fungsi untuk membuat akun pegawai baru
export const createPegawai = onCall(async (request) => {
  if (request.auth?.token.role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Hanya admin yang bisa membuat akun.",
    );
  }

  const {nama, email, password, organisasi, kodeOrganisasi} =
    request.data as CreatePegawaiData;

  try {
    const userRecord = await auth.createUser({email, password, displayName: nama});
    await auth.setCustomUserClaims(userRecord.uid, {role: "pegawai"});
    await db.collection("users").doc(userRecord.uid).set({
      nama,
      email,
      role: "pegawai",
      organisasi,
      kodeOrganisasi,
    });
    return {success: true, uid: userRecord.uid};
  } catch (error) {
    throw new HttpsError("internal", "Gagal membuat akun.", error);
  }
});

// Fungsi untuk mengedit data pegawai
export const updatePegawai = onCall(async (request) => {
  if (request.auth?.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Akses ditolak.");
  }

  const {uid, newEmail, newPassword} = request.data as UpdatePegawaiData;
  const updateAuthData: { email?: string; password?: string } = {};

  if (newEmail) {
    updateAuthData.email = newEmail;
  }
  if (newPassword) {
    updateAuthData.password = newPassword;
  }

  try {
    await auth.updateUser(uid, updateAuthData);
    if (newEmail) {
      await db.collection("users").doc(uid).update({email: newEmail});
    }
    return {success: true};
  } catch (error) {
    throw new HttpsError("internal", "Gagal mengedit akun.", error);
  }
});

// Fungsi untuk menghapus akun pegawai
export const deletePegawai = onCall(async (request) => {
  if (request.auth?.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Akses ditolak.");
  }

  const {uid} = request.data as DeletePegawaiData;

  try {
    await auth.deleteUser(uid);
    await db.collection("users").doc(uid).delete();
    return {success: true};
  } catch (error) {
    throw new HttpsError("internal", "Gagal menghapus akun.", error);
  }
});