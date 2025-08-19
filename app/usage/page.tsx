"use client"

import { useEffect, useState } from 'react'
import { useSearchParams } from 'next/navigation'
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { CircularProgress } from '@/components/ui/circular-progress'
import { toast } from 'sonner'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Terminal, ArrowLeft, RefreshCw } from 'lucide-react'
import { Skeleton } from '@/components/ui/skeleton'
import Link from "next/link"

interface ClientData {
    traffic_id: number
    email: string
    inbound_id: number
    client_id: string
    enable: number
    expiry_time: string
    upGB: string
    downGB: string
    totalGB: string
}

export default function UsagePage() {
    const searchParams = useSearchParams()
    const clientId = searchParams.get('clientId')
    const [data, setData] = useState<ClientData | null>(null)
    const [isLoading, setIsLoading] = useState(true)
    const [error, setError] = useState<string | null>(null)
    const [isRefreshing, setIsRefreshing] = useState(false)

    const fetchData = async () => {
        try {
            setIsRefreshing(true)
            setError(null)

            if (!clientId) {
                throw new Error('No client ID provided')
            }

            const response = await fetch('/api', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ clientId }),
            })

            if (!response.ok) {
                const errorData = await response.json()
                throw new Error(errorData.error || 'Failed to fetch data')
            }

            const result = await response.json()
            setData(result)
        } catch (err) {
            console.error('Error fetching data:', err)
            setError(err instanceof Error ? err.message : 'An unknown error occurred')
            toast.error('Failed to fetch client data')
        } finally {
            setIsLoading(false)
            setIsRefreshing(false)
        }
    }

    useEffect(() => {
        fetchData()
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [clientId])

    const handleRefresh = () => {
        fetchData()
    }

    if (isLoading && !isRefreshing) {
        return (
            <div className="min-h-screen flex items-center justify-center p-4">
                <Card className="w-full max-w-md">
                    <CardHeader>
                        <CardTitle>
                            <Skeleton className="h-6 w-3/4" />
                        </CardTitle>
                        <CardDescription>
                            <Skeleton className="h-4 w-full mt-2" />
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-4">
                        <div className="flex justify-center">
                            <Skeleton className="h-64 w-64 rounded-full" />
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                            {[...Array(6)].map((_, i) => (
                                <div key={i} className="space-y-2">
                                    <Skeleton className="h-4 w-3/4" />
                                    <Skeleton className="h-6 w-full" />
                                </div>
                            ))}
                        </div>
                        <Skeleton className="h-10 w-full mt-6" />
                    </CardContent>
                </Card>
            </div>
        )
    }

    if (error) {
        return (
            <div className="min-h-screen flex items-center justify-center p-4">
                <Alert variant="destructive" className="max-w-md w-full">
                    <Terminal className="h-4 w-4" />
                    <AlertTitle>Error</AlertTitle>
                    <AlertDescription>
                        {error}
                        <div className="mt-4 flex flex-col sm:flex-row gap-2">
                            <Button variant="outline" onClick={() => window.location.href = '/'}>
                                <ArrowLeft className="mr-2 h-4 w-4" />
                                Back to Home
                            </Button>
                            <Button onClick={handleRefresh} disabled={isRefreshing}>
                                {isRefreshing ? (
                                    <RefreshCw className="mr-2 h-4 w-4 animate-spin" />
                                ) : (
                                    <RefreshCw className="mr-2 h-4 w-4" />
                                )}
                                Try Again
                            </Button>
                        </div>
                    </AlertDescription>
                </Alert>
            </div>
        )
    }

    if (!data) {
        return (
            <div className="min-h-screen flex items-center justify-center p-4">
                <Alert variant="destructive" className="max-w-md w-full">
                    <Terminal className="h-4 w-4" />
                    <AlertTitle>No Data Found</AlertTitle>
                    <AlertDescription>
                        No client data was found for the provided identifier.
                        <div className="mt-4 flex flex-col sm:flex-row gap-2">
                            <Button variant="outline" onClick={() => window.location.href = '/'}>
                                <ArrowLeft className="mr-2 h-4 w-4" />
                                Back to Home
                            </Button>
                            <Button onClick={handleRefresh} disabled={isRefreshing}>
                                {isRefreshing ? (
                                    <RefreshCw className="mr-2 h-4 w-4 animate-spin" />
                                ) : (
                                    <RefreshCw className="mr-2 h-4 w-4" />
                                )}
                                Try Again
                            </Button>
                        </div>
                    </AlertDescription>
                </Alert>
            </div>
        )
    }

    // Calculate usage values
    const totalUsed = parseFloat(data.upGB) + parseFloat(data.downGB)
    const remaining = parseFloat(data.totalGB) - totalUsed
    const usagePercentage = (totalUsed / parseFloat(data.totalGB)) * 100

    return (
        <div className="min-h-screen p-4">
            <div className="max-w-4xl mx-auto py-8">
                <Card>
                    <CardHeader>
                        <div className="flex justify-between items-start">
                            <div>
                                <Link
                                    href='/'
                                    className="w-full sm:w-auto"
                                >
                                    <CardTitle className="text-xl sm:text-2xl">Client Usage</CardTitle>
                                </Link>

                                <CardDescription className="truncate max-w-[90%]">
                                    {data.email}
                                </CardDescription>
                            </div>
                            <Button
                                size="sm"
                                variant="outline"
                                onClick={handleRefresh}
                                disabled={isRefreshing}
                            >
                                {isRefreshing ? (
                                    <RefreshCw className="h-4 w-4 animate-spin" />
                                ) : (
                                    <RefreshCw className="h-4 w-4" />
                                )}
                                <span className="sr-only">Refresh</span>
                            </Button>
                        </div>
                    </CardHeader>
                    <CardContent>
                        <div className="flex flex-col items-center mb-6">
                            <CircularProgress
                                max={parseFloat(data.totalGB)}
                                segments={[
                                    {
                                        value: parseFloat((parseFloat(data.downGB)).toFixed(2)),
                                        color: "text-blue-500",
                                        label: "Download"
                                    },
                                    {
                                        value: parseFloat((parseFloat(data.upGB)).toFixed(2)),
                                        color: "text-green-500",
                                        label: "Upload"
                                    },
                                ]}
                                formatLabel={() => `${totalUsed.toFixed(1)} GB / ${parseFloat(data.totalGB).toFixed(1)} GB`}
                                size="xl"
                                thickness={8}
                                showLegend={true}
                                animated={true}
                            />
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                            <StatCard
                                title="Remaining"
                                value={`${remaining.toFixed(2)} GB`}
                                description={`${Math.max(0, (100 - usagePercentage)).toFixed(1)}% of total`}
                            />
                            <StatCard
                                title="Usage"
                                value={`${totalUsed.toFixed(2)} GB`}
                                description={`${usagePercentage.toFixed(1)}% of total`}
                            />
                            <StatCard
                                title="Total"
                                value={`${parseFloat(data.totalGB).toFixed(2)} GB`}
                                description="Data allowance"
                            />
                            <StatCard
                                title="Upload"
                                value={`${data.upGB} GB`}
                                description={`${(parseFloat(data.upGB) / totalUsed * 100).toFixed(1)}% of usage`}
                            />
                            <StatCard
                                title="Download"
                                value={`${data.downGB} GB`}
                                description={`${(parseFloat(data.downGB) / totalUsed * 100).toFixed(1)}% of usage`}
                            />

                            <StatCard
                                title="Status"
                                value={data.enable ? "Active" : "Disabled"}
                                description={`Expires: ${data.expiry_time}`}
                                valueColor={data.enable ? "text-green-500" : "text-red-500"}
                            />
                        </div>
                    </CardContent>
                </Card>
            </div>
        </div>
    )
}

function StatCard({
    title,
    value,
    description,
    valueColor = "text-foreground"
}: {
    title: string;
    value: string;
    description: string;
    valueColor?: string;
}) {
    return (
        <div className="border rounded-lg p-4">
            <h3 className="text-sm font-medium text-muted-foreground">{title}</h3>
            <p className={`text-2xl font-bold mt-1 ${valueColor}`}>{value}</p>
            <p className="text-sm text-muted-foreground mt-1">{description}</p>
        </div>
    )
}