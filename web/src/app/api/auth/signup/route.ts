import { NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";

export async function POST(request: Request) {
  try {
    const { email, password, name } = await request.json();

    if (!email || !password) {
      return NextResponse.json(
        { error: "Email and password are required" },
        { status: 400 }
      );
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      // Return 201 with same shape to prevent email enumeration
      return NextResponse.json(
        { id: existing.id, email: existing.email },
        { status: 201 }
      );
    }

    const hashedPassword = await bcrypt.hash(password, 12);

    const user = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        name: name || null,
        emailVerified: new Date(),
      },
    });

    // Register with backend
    try {
      const backendUser = await backendClient("/users/web-register", {
        method: "POST",
        body: JSON.stringify({
          email,
          display_name: name || null,
          web_user_id: user.id,
        }),
      });

      await prisma.user.update({
        where: { id: user.id },
        data: { backendUserId: backendUser.id },
      });
    } catch (err) {
      console.error("Failed to register with backend:", err);
    }

    return NextResponse.json(
      { id: user.id, email: user.email },
      { status: 201 }
    );
  } catch (error) {
    console.error("Signup error:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
