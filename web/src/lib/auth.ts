import { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";
import { PrismaAdapter } from "@auth/prisma-adapter";
import bcrypt from "bcryptjs";
import { prisma } from "./prisma";
import { backendClient } from "./backend-client";

// Check if we're in local dev mode (no password required)
const isLocalDev = process.env.NODE_ENV === "development" && process.env.NEXTAUTH_URL?.includes("localhost");

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma) as NextAuthOptions["adapter"],
  providers: [
    // Auto-login provider for local development
    CredentialsProvider({
      id: "local-dev",
      name: "Local Development",
      credentials: {},
      async authorize() {
        if (!isLocalDev) {
          throw new Error("Local dev login only available in development");
        }

        // Find or create the local dev user
        let user = await prisma.user.findUnique({
          where: { email: "local@outlive.dev" },
        });

        if (!user) {
          user = await prisma.user.create({
            data: {
              email: "local@outlive.dev",
              name: "Local User",
              emailVerified: new Date(),
              onboardingComplete: true,
            },
          });
        }

        // Ensure backend user exists
        if (!user.backendUserId) {
          try {
            const backendUser = await backendClient("/users/web-register", {
              method: "POST",
              body: JSON.stringify({
                email: "local@outlive.dev",
                display_name: "Local User",
                web_user_id: user.id,
              }),
            });

            user = await prisma.user.update({
              where: { id: user.id },
              data: { backendUserId: backendUser.id },
            });
          } catch (err) {
            console.error("Failed to register with backend:", err);
          }
        }

        return { id: user.id, email: user.email, name: user.name };
      },
    }),
    CredentialsProvider({
      name: "credentials",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          throw new Error("Invalid credentials");
        }

        const user = await prisma.user.findUnique({
          where: { email: credentials.email },
        });

        if (!user || !user.password) {
          throw new Error("Invalid credentials");
        }

        const isValid = await bcrypt.compare(credentials.password, user.password);
        if (!isValid) {
          throw new Error("Invalid credentials");
        }

        return { id: user.id, email: user.email, name: user.name };
      },
    }),
    CredentialsProvider({
      id: "magic-link",
      name: "Magic Link",
      credentials: {
        token: { label: "Token", type: "text" },
      },
      async authorize(credentials) {
        if (!credentials?.token) {
          throw new Error("No token provided");
        }

        const verification = await prisma.verificationToken.findFirst({
          where: {
            token: credentials.token,
            expires: { gt: new Date() },
          },
        });

        if (!verification) {
          throw new Error("Invalid or expired token");
        }

        const user = await prisma.user.findUnique({
          where: { email: verification.identifier },
        });

        if (!user) {
          throw new Error("User not found");
        }

        await prisma.verificationToken.delete({
          where: {
            identifier_token: {
              identifier: verification.identifier,
              token: verification.token,
            },
          },
        });

        if (!user.emailVerified) {
          await prisma.user.update({
            where: { id: user.id },
            data: { emailVerified: new Date() },
          });
        }

        return { id: user.id, email: user.email, name: user.name };
      },
    }),
  ],
  session: {
    strategy: "jwt",
  },
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.id = user.id;
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.id = token.id as string;
      }
      return session;
    },
  },
  pages: {
    signIn: "/login",
  },
};
