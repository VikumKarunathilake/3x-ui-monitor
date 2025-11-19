import { NextRequest, NextResponse } from "next/server";

const rateLimit = new Map<string, { count: number; resetTime: number }>();

export function middleware(request: NextRequest) {
  // Handle CORS for API routes
  if (request.nextUrl.pathname.startsWith("/api/")) {
    // Rate limiting ( 5 req/mine )
    const ip =
      request.headers.get("x-real-ip") ||
      request.headers.get("x-forwarded-for") ||
      "unknown";
    const now = Date.now();
    const windowMs = 60 * 1000; // 1 minute
    const maxRequests = 5; // Max 5 requests per window

    const current = rateLimit.get(ip);
    if (!current || now > current.resetTime) {
      rateLimit.set(ip, { count: 1, resetTime: now + windowMs });
    } else if (current.count >= maxRequests) {
      return NextResponse.json(
        { error: "Too many requests" },
        { status: 429, headers: { "Content-Type": "application/json" } }
      );
    } else {
      current.count++;
    }

    const response = NextResponse.next();

    response.headers.set("Access-Control-Allow-Origin", "*");
    response.headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    response.headers.set("Access-Control-Allow-Headers", "Content-Type");

    // Handle preflight requests
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 200, headers: response.headers });
    }

    return response;
  }

  return NextResponse.next();
}

export const config = {
  matcher: "/api/:path*",
};
