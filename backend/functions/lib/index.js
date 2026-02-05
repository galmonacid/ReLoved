"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendContactEmail = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const sgMail = require("@sendgrid/mail");
admin.initializeApp();
/**
 * MVP placeholder: send contact email to item owner.
 *
 * Recommended implementation:
 * - Verify user is authenticated
 * - Fetch item + owner
 * - Rate limit per sender
 * - Use SendGrid/Mailgun to send an email to owner with Reply-To set to sender email
 */
exports.sendContactEmail = functions.https.onCall(async (data, context) => {
    try {
        functions.logger.info("sendContactEmail request", {
            hasAuth: Boolean(context.auth),
            hasAppCheck: Boolean(context.app),
            dataKeys: data && typeof data === "object" ? Object.keys(data) : []
        });
        if (!context.auth) {
            throw new functions.https.HttpsError("unauthenticated", "Authentication required");
        }
        functions.logger.info("sendContactEmail invoked", {
            uid: context.auth.uid
        });
        const isEmulator = Boolean(process.env.FIREBASE_EMULATOR_HUB);
        const sendgridKey = functions.config().sendgrid?.key
            ?? (isEmulator ? process.env.SENDGRID_KEY : undefined);
        let sendgridFrom = functions.config().sendgrid?.from
            ?? (isEmulator ? process.env.SENDGRID_FROM : undefined);
        if (!sendgridFrom && isEmulator) {
            sendgridFrom = "noreply@localhost";
        }
        if (!isEmulator && (!sendgridKey || !sendgridFrom)) {
            throw new functions.https.HttpsError("failed-precondition", "SendGrid not configured");
        }
        const { itemId, message } = data || {};
        if (!itemId || typeof itemId !== "string") {
            throw new functions.https.HttpsError("invalid-argument", "itemId is required");
        }
        if (!message || typeof message !== "string") {
            throw new functions.https.HttpsError("invalid-argument", "message is required");
        }
        const trimmedMessage = message.trim();
        if (trimmedMessage.length < 1 || trimmedMessage.length > 1000) {
            throw new functions.https.HttpsError("invalid-argument", "message length is invalid");
        }
        const senderId = context.auth.uid;
        const senderEmail = context.auth.token.email;
        if (!senderEmail) {
            throw new functions.https.HttpsError("failed-precondition", "Sender email missing");
        }
        const itemRef = admin.firestore().collection("items").doc(itemId);
        const itemSnap = await itemRef.get();
        if (!itemSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Item not found");
        }
        const itemData = itemSnap.data() || {};
        const ownerId = itemData.ownerId;
        if (!ownerId || typeof ownerId !== "string") {
            throw new functions.https.HttpsError("failed-precondition", "Item owner missing");
        }
        if (ownerId === senderId) {
            throw new functions.https.HttpsError("invalid-argument", "Cannot contact your own item");
        }
        const recentSnap = await admin
            .firestore()
            .collection("contactRequests")
            .where("fromUserId", "==", senderId)
            .orderBy("createdAt", "desc")
            .limit(1)
            .get();
        if (!recentSnap.empty) {
            const lastCreatedAt = recentSnap.docs[0].get("createdAt");
            if (lastCreatedAt && lastCreatedAt.toMillis) {
                const elapsedMs = Date.now() - lastCreatedAt.toMillis();
                if (elapsedMs < 60 * 1000) {
                    throw new functions.https.HttpsError("resource-exhausted", "Too many requests");
                }
            }
        }
        let ownerEmail;
        const ownerSnap = await admin.firestore().collection("users").doc(ownerId).get();
        if (ownerSnap.exists) {
            const ownerData = ownerSnap.data() || {};
            if (typeof ownerData.email === "string") {
                ownerEmail = ownerData.email;
            }
        }
        if (!ownerEmail) {
            try {
                const ownerAuth = await admin.auth().getUser(ownerId);
                ownerEmail = ownerAuth.email || undefined;
            }
            catch (error) {
                const err = error;
                functions.logger.error("Owner lookup failed", {
                    ownerId,
                    message: err?.message,
                    code: err?.code
                });
            }
        }
        if (!ownerEmail) {
            throw new functions.https.HttpsError("failed-precondition", "Owner email missing");
        }
        if (!isEmulator && sendgridKey) {
            sgMail.setApiKey(sendgridKey);
        }
        const title = typeof itemData.title === "string" ? itemData.title : "tu objeto";
        const approxArea = itemData.location && typeof itemData.location.approxAreaText === "string"
            ? itemData.location.approxAreaText
            : "zona aproximada";
        const subject = `ReLoved: interesado en "${title}"`;
        const text = [
            `Mensaje de: ${senderEmail}`,
            `Item: ${title}`,
            `Zona: ${approxArea}`,
            "",
            trimmedMessage
        ].join("\n");
        let sent = false;
        let errorMessage = null;
        if (isEmulator) {
            sent = true;
        }
        else {
            try {
                await sgMail.send({
                    to: ownerEmail,
                    from: sendgridFrom,
                    replyTo: senderEmail,
                    subject,
                    text
                });
                sent = true;
            }
            catch (error) {
                const err = error;
                errorMessage = err && err.message ? err.message : "Unknown error";
                functions.logger.error("SendGrid send failed", {
                    message: err?.message,
                    code: err?.code,
                    responseBody: err?.response?.body
                });
            }
        }
        await admin.firestore().collection("contactRequests").add({
            fromUserId: senderId,
            fromEmail: senderEmail,
            toUserId: ownerId,
            toEmail: ownerEmail,
            itemId,
            itemTitle: title,
            itemStatus: typeof itemData.status === "string" ? itemData.status : null,
            itemApproxArea: approxArea,
            subject,
            message: trimmedMessage,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            sentAt: sent ? admin.firestore.FieldValue.serverTimestamp() : null,
            sent,
            error: errorMessage
        });
        if (!sent) {
            throw new functions.https.HttpsError("internal", errorMessage ? `Failed to send email: ${errorMessage}` : "Failed to send email");
        }
        return { ok: true };
    }
    catch (error) {
        const err = error;
        if (error instanceof functions.https.HttpsError) {
            functions.logger.error("sendContactEmail failed (HttpsError)", {
                message: err?.message,
                code: err?.code,
                details: err?.details
            });
            throw error;
        }
        functions.logger.error("sendContactEmail failed (unexpected)", {
            message: err?.message,
            code: err?.code,
            details: err?.details,
            stack: err?.stack
        });
        throw new functions.https.HttpsError("internal", err?.message ?? "Unexpected error");
    }
});
//# sourceMappingURL=index.js.map