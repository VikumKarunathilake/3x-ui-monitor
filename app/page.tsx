"use client"

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card'
import { toast } from 'sonner'

export default function Home() {
  const [input, setInput] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const router = useRouter()

  const extractClientId = (input: string): string | null => {
    const trimmed = input.trim()

    // Check if it's a valid UUID
    if (uuidValidate(trimmed)) {
      return trimmed
    }

    // Check if it's a V2Ray config URL
    if (trimmed.startsWith('vless://') || trimmed.startsWith('vmess://') || trimmed.startsWith('hysteria://')) {
      try {
        const url = new URL(trimmed)
        const clientId = url.username

        if (clientId && uuidValidate(clientId)) {
          return clientId
        }

        // Try to extract from search params for some config types
        const params = new URLSearchParams(url.search)
        const idParam = params.get('id') || params.get('uuid')

        if (idParam && uuidValidate(idParam)) {
          return idParam
        }
      } catch {
        return null
      }
    }

    return null
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!input.trim()) {
      toast.error('Please enter an UUID or V2Ray config')
      return
    }

    const clientId = extractClientId(input)

    if (!clientId) {
      toast.error('Invalid UUID or V2Ray config format')
      return
    }

    setIsLoading(true)
    router.push(`/usage?clientId=${encodeURIComponent(clientId)}`)
  }

  return (
    <div className="min-h-screen flex items-center justify-center">
      <Card className="w-full max-w-md shadow-lg">
        <CardHeader className="text-center">
          <CardTitle className="text-2xl font-bold">
            Usage Tracker
          </CardTitle>
          <CardDescription className="text-gray-600 dark:text-gray-300">
            Enter your client Config or UUID to view usage statistics
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <Input
                type="text"
                placeholder="vless://uuid@domain:443?security=tls&type=ws#config-name or UUID"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                className="w-full"
                disabled={isLoading}
              />
            </div>
            <Button
              type="submit"
              className="w-full transition-colors"
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Loading...
                </>
              ) : (
                'View Usage'
              )}
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}

// UUID validation function (you might want to move this to a utils file)
function uuidValidate(uuid: string): boolean {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  return uuidRegex.test(uuid)
}