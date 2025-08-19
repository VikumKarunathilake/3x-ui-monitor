// route.ts
import { type NextRequest, NextResponse } from "next/server"
import Database from "better-sqlite3"
import path from "path"
import { RateLimiterMemory } from "rate-limiter-flexible"
import { validate as uuidValidate } from "uuid"

interface Client {
  id: string
  email: string
  [key: string]: unknown // optional extra fields
}


// Rate limiting configuration (10 requests per minute)
const rateLimiter = new RateLimiterMemory({
  points: 100, // 10 requests
  duration: 1, // per 1 seconds
})

// Path to SQLite DB
const dbPath = path.join(process.cwd(), "data", "x-ui.db")
const db = new Database(dbPath, { readonly: false }) // Open in read-only mode

// Enable WAL mode for better concurrency
db.pragma("journal_mode = WAL")

function formatExpiry(expiry: number): string {
  if (expiry === 0) return "∞"
  const now = Date.now()
  const remaining = expiry - now

  if (remaining <= 0) return "Expired"

  const days = Math.floor(remaining / (1000 * 60 * 60 * 24))
  const hours = Math.floor((remaining / (1000 * 60 * 60)) % 24)
  const minutes = Math.floor((remaining / (1000 * 60)) % 60)
  const seconds = Math.floor((remaining / 1000) % 60)

  return `${days}d ${hours}h ${minutes}m ${seconds}s`
}

export async function POST(req: NextRequest) {
  try {
    // Rate limiting check using IP address
    const ip = req.headers.get('x-real-ip') || req.headers.get('x-forwarded-for') || 'unknown'
    try {
  await rateLimiter.consume(ip)
} catch {
  return NextResponse.json(
    { error: 'Too many requests. Please try again later.' },
    { status: 429 }
  )
}


    // Only accept POST requests
    if (req.method !== 'POST') {
      return NextResponse.json({ error: 'Method not allowed' }, { status: 405 })
    }

    // Get clientId from request body
    const { clientId } = await req.json()
    
    // Input validation
    if (!clientId) {
      return NextResponse.json({ error: 'Client ID is required' }, { status: 400 })
    }

    // Validate UUID format
    if (!uuidValidate(clientId)) {
      return NextResponse.json({ error: 'Invalid Client' }, { status: 400 })
    }

    // Prepare statement to find client by ID in JSON settings
    // This query joins client_traffics with inbounds and uses JSON functions to search
    const clientQuery = db.prepare(`
      SELECT 
        ct.id AS traffic_id,
        ct.email,
        ct.inbound_id,
        ct.up,
        ct.down,
        ct.total,
        ct.expiry_time,
        ct.enable,
        i.settings AS inbound_settings
      FROM client_traffics ct
      JOIN inbounds i ON ct.inbound_id = i.id
      WHERE EXISTS (
        SELECT 1 FROM json_each(i.settings, '$.clients') 
        WHERE json_extract(value, '$.id') = @clientId
        AND json_extract(value, '$.email') = ct.email
      )
      LIMIT 1
    `)

    // Execute query with parameter binding to prevent SQL injection
    const clientData = clientQuery.get({ clientId }) as {
      traffic_id: number
      email: string
      inbound_id: number
      up: number
      down: number
      total: number
      expiry_time: number
      enable: number
      inbound_settings: string
    } | undefined

    if (!clientData) {
      return NextResponse.json({ error: "Client not found" }, { status: 404 })
    }

    // Extract client_id from settings
    let clientIdFromSettings: string | null = null
try {
  const settings = JSON.parse(clientData.inbound_settings) as { clients?: Client[] }

  if (Array.isArray(settings.clients)) {
    const match = settings.clients.find((c: Client) => c.email === clientData.email)
    if (match) clientIdFromSettings = match.id
  }
} catch (err) {
  console.error("Error parsing inbound settings:", err)
}


    // Format the response
    const result = {
      traffic_id: clientData.traffic_id,
      email: clientData.email,
      inbound_id: clientData.inbound_id,
      client_id: clientIdFromSettings,
      enable: clientData.enable,
      expiry_time: formatExpiry(clientData.expiry_time),
      upGB: (clientData.up / 1024 / 1024 / 1024).toFixed(2),
      downGB: (clientData.down / 1024 / 1024 / 1024).toFixed(2),
      totalGB: (clientData.total / 1024 / 1024 / 1024).toFixed(2),
    }

    return NextResponse.json(result)
  } catch (err) {
    console.error(err)
    return NextResponse.json({ error: "Failed to fetch data" }, { status: 500 })
  }
}

// Add this to explicitly reject other methods
export async function GET() {
  return NextResponse.json({ error: 'Method not allowed' }, { status: 405 })
}