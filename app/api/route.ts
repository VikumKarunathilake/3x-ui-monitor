// route.ts
import { type NextRequest, NextResponse } from "next/server"
import Database from "better-sqlite3"

import { validate as uuidValidate } from "uuid"

interface Client {
  id: string
  email: string
  [key: string]: unknown // optional extra fields
}

interface ClientTrafficData {
  traffic_id: number
  email: string
  inbound_id: number
  up: number
  down: number
  total: number
  expiry_time: number
  enable: number
  inbound_settings: string
}

interface InboundSettings {
  clients?: Client[]
}



// Database connection management (singleton pattern)
let db: Database.Database | null = null

function getDatabase(): Database.Database {
  if (!db) {
    // Try multiple possible database locations
    const possiblePaths = [
      "/etc/x-ui/x-ui.db",
      "./data/x-ui.db",
      process.env.DATABASE_PATH || "/etc/x-ui/x-ui.db"
    ]
    
    let dbPath = possiblePaths[0]
    // In development, use local data directory
    if (process.env.NODE_ENV === 'development') {
      dbPath = "./data/x-ui.db"
    }
    
    db = new Database(dbPath, { readonly: false })
    
    // Enable WAL mode for better concurrency
    db.pragma("journal_mode = WAL")
    
    // Enable foreign key constraints
    db.pragma("foreign_keys = ON")
  }
  return db
}

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

const responseHeaders = {
  'Content-Type': 'application/json'
}

export async function POST(req: NextRequest) {
  try {


    // Only accept POST requests
    if (req.method !== 'POST') {
      return NextResponse.json(
        { error: 'Method not allowed' }, 
        { 
          status: 405,
          headers: responseHeaders
        }
      )
    }

    // Get clientId from request body
    const { clientId } = await req.json()
    
    // Input validation
    if (!clientId) {
      return NextResponse.json(
        { error: 'Client ID is required' }, 
        { 
          status: 400,
          headers: responseHeaders
        }
      )
    }

    // Validate UUID format
    if (!uuidValidate(clientId)) {
      return NextResponse.json(
        { error: 'Invalid Client ID format' }, 
        { 
          status: 400,
          headers: responseHeaders
        }
      )
    }

    // Get database instance
    const db = getDatabase()

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
        WHERE json_extract(value, '$.id') = ?
        AND json_extract(value, '$.email') = ct.email
      )
      LIMIT 1
    `)

    // Execute query with parameter binding to prevent SQL injection
    const clientData = clientQuery.get(clientId) as ClientTrafficData | undefined

    if (!clientData) {
      return NextResponse.json(
        { error: "Client not found" }, 
        { 
          status: 404,
          headers: responseHeaders
        }
      )
    }

    // Extract client_id from settings
    let clientIdFromSettings: string | null = null
    try {
      const settings = JSON.parse(clientData.inbound_settings) as InboundSettings

      if (Array.isArray(settings.clients)) {
        const match = settings.clients.find((c: Client) => c.email === clientData.email)
        if (match) clientIdFromSettings = match.id
      }
    } catch (err) {
      console.error("Error parsing inbound settings:", err)
      // Continue even if parsing fails - we'll just have null for clientIdFromSettings
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

    return NextResponse.json(result, { headers: responseHeaders })
  } catch (err) {
    console.error('Database error:', err)
    
    // Handle specific database errors
    if (err instanceof Error) {
      if (err.message.includes('SQLITE_')) {
        return NextResponse.json(
          { error: "Database error occurred" }, 
          { 
            status: 500,
            headers: responseHeaders
          }
        )
      }
    }
    
    return NextResponse.json(
      { error: "Failed to fetch data" }, 
      { 
        status: 500,
        headers: responseHeaders
      }
    )
  }
}

// Add this to explicitly reject other methods
export async function GET() {
  return NextResponse.json(
    { error: 'Method not allowed' }, 
    { 
      status: 405,
      headers: responseHeaders
    }
  )
}

