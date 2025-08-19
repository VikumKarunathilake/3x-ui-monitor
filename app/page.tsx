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

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!input.trim()) {
      toast.error('Please enter an UUID or V2Ray config')
      return
    }

    let clientId = input.trim()

    // Check if input is a V2Ray config
    if (clientId.startsWith('vless://') || clientId.startsWith('vmess://') || clientId.startsWith('hysteria://')) {
      try {
        const url = new URL(clientId)
        // Extract UUID from username part (before @)
        clientId = url.username
        if (!clientId) {
          toast.error('Invalid V2Ray config: missing UUID')
          return
        }
      } catch {
        toast.error('Invalid V2Ray config format')
        return
      }
    }

    setIsLoading(true)
    // Navigate to usage page with the extracted clientId
    router.push(`/usage?clientId=${encodeURIComponent(clientId)}`)
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl font-bold text-center">Usage Tracker</CardTitle>
          <CardDescription className="text-center">
            Enter your client Config or UUID to view usage statistics
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <Input
                type="text"
                placeholder="Config or UUID"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                className="w-full"
              />
            </div>
            <Button type="submit" className="w-full" disabled={isLoading}>
              {isLoading ? (
                <>
                  <svg className="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
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