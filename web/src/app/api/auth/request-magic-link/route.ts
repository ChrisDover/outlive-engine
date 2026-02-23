import { NextResponse } from "next/server";
import crypto from "crypto";
import { prisma } from "@/lib/prisma";
import { Resend } from "resend";

export async function POST(request: Request) {
  try {
    const { email } = await request.json();

    if (!email) {
      return NextResponse.json({ error: "Email is required" }, { status: 400 });
    }

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      // Don't reveal whether email exists
      return NextResponse.json({ message: "If that email exists, a magic link has been sent." });
    }

    const token = crypto.randomBytes(32).toString("hex");
    const expires = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    await prisma.verificationToken.create({
      data: { identifier: email, token, expires },
    });

    const magicUrl = `${process.env.NEXTAUTH_URL}/api/auth/validate-magic-token?token=${token}`;

    if (process.env.RESEND_API_KEY) {
      const resend = new Resend(process.env.RESEND_API_KEY);
      await resend.emails.send({
        from: "Outlive Engine <noreply@outlive.engine>",
        to: email,
        subject: "Your login link",
        html: `<p>Click <a href="${magicUrl}">here</a> to log in. This link expires in 15 minutes.</p>`,
      });
    } else {
      console.log("Magic link (no Resend key):", magicUrl);
    }

    return NextResponse.json({ message: "If that email exists, a magic link has been sent." });
  } catch (error) {
    console.error("Magic link error:", error);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
