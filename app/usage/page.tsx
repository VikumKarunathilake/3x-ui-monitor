"use client"

import { useEffect, useState, useCallback } from 'react'
import { useSearchParams } from 'next/navigation'
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { CircularProgress } from '@/components/ui/circular-progress'
import { toast } from 'sonner'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Terminal, ArrowLeft, RefreshCw, Wifi, WifiOff, Calendar } from 'lucide-react'
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

type LoadingState = 'initial' | 'loading' | 'success' | 'error'

export default function UsagePage() {
    const searchParams = useSearchParams()
    const clientId = searchParams.get('clientId')
    const [data, setData] = useState<ClientData | null>(null)
    const [loadingState, setLoadingState] = useState<LoadingState>('initial')
    const [error, setError] = useState<string | null>(null)
    const [isRefreshing, setIsRefreshing] = useState(false)

    const fetchData = useCallback(async () => {
        try {
            if (loadingState !== 'initial') {
                setIsRefreshing(true)
            } else {
                setLoadingState('loading')
            }
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
            setLoadingState('success')
            setIsRefreshing(false)
        } catch (err) {
            console.error('Error fetching data:', err)
            const errorMessage = err instanceof Error ? err.message : 'An unknown error occurred'
            setError(errorMessage)
            setLoadingState('error')
            setIsRefreshing(false)
            toast.error('Failed to fetch client data')
        }
    }, [clientId, loadingState])

    useEffect(() => {
        if (clientId && loadingState === 'initial') {
            fetchData()
        }
    }, [clientId, loadingState, fetchData])

    const handleRefresh = () => {
        fetchData()
    }

    // Show loading skeleton only during initial load and loading state
    if (loadingState === 'initial' || loadingState === 'loading') {
        return (
            <div className="min-h-screen flex items-center justify-center p-4 bg-background">
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

    if (loadingState === 'error') {
        return (
            <div className="min-h-screen flex items-center justify-center p-4 bg-background">
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
            <div className="min-h-screen flex items-center justify-center p-4 bg-background">
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
    const remaining = Math.max(0, parseFloat(data.totalGB) - totalUsed)
    const usagePercentage = parseFloat(data.totalGB) > 0
        ? (totalUsed / parseFloat(data.totalGB)) * 100
        : 0

    return (
        <div className="min-h-screen p-4 bg-background">
            <div className="max-w-4xl mx-auto py-8">
                <Card className="shadow-lg">
                    <CardHeader>
                        <div className="flex justify-between items-start">
                            <div>
                                <Link href='/' className="inline-block mb-2">
                                    <Button variant="ghost" size="sm">
                                        <ArrowLeft className="mr-2 h-4 w-4" />
                                        Back to Home
                                    </Button>
                                </Link>
                                <CardTitle className="text-xl sm:text-2xl">
                                    Client Usage Dashboard
                                </CardTitle>
                                <CardDescription className="truncate max-w-[90%]">
                                    {data.email}
                                </CardDescription>
                            </div>
                            <Button
                                size="sm"
                                variant="outline"
                                onClick={handleRefresh}
                                disabled={isRefreshing}
                                className="flex items-center"
                            >
                                {isRefreshing ? (
                                    <RefreshCw className="h-4 w-4 animate-spin mr-1" />
                                ) : (
                                    <RefreshCw className="h-4 w-4 mr-1" />
                                )}
                                Refresh
                            </Button>
                        </div>
                    </CardHeader>
                    <CardContent>
                        <div className="flex flex-col items-center mb-8">
                            <CircularProgress
                                max={parseFloat(data.totalGB)}
                                segments={[
                                    {
                                        value: parseFloat(data.downGB),
                                        color: "text-blue-500",
                                        label: "Download"
                                    },
                                    {
                                        value: parseFloat(data.upGB),
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

                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
                            <StatCard
                                title="Remaining Data"
                                value={`${remaining.toFixed(2)} GB`}
                                description={`${Math.max(0, (100 - usagePercentage)).toFixed(1)}% of total`}
                                icon={<Wifi className="h-5 w-5 text-blue-500" />}
                            />
                            <StatCard
                                title="Total Used"
                                value={`${totalUsed.toFixed(2)} GB`}
                                description={`${usagePercentage.toFixed(1)}% of total`}
                                icon={<WifiOff className="h-5 w-5 text-orange-500" />}
                            />
                            <StatCard
                                title="Total Allowance"
                                value={`${parseFloat(data.totalGB).toFixed(2)} GB`}
                                description="Data allocation"
                                icon={<div className="h-5 w-5 text-purple-500 font-bold">∑</div>}
                            />
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                            <StatCard
                                title="Upload"
                                value={`${data.upGB} GB`}
                                description={totalUsed > 0 ? `${(parseFloat(data.upGB) / totalUsed * 100).toFixed(1)}% of usage` : "0% of usage"}
                            />
                            <StatCard
                                title="Download"
                                value={`${data.downGB} GB`}
                                description={totalUsed > 0 ? `${(parseFloat(data.downGB) / totalUsed * 100).toFixed(1)}% of usage` : "0% of usage"}
                            />
                            <StatCard
                                title="Status"
                                value={data.enable ? "Active" : "Disabled"}
                                description={`Expires: ${data.expiry_time}`}
                                icon={data.enable ?
                                    <div className="h-3 w-3 bg-green-500 rounded-full animate-pulse"></div> :
                                    <div className="h-3 w-3 bg-red-500 rounded-full"></div>
                                }
                            />
                        </div>

                        <div className="mt-6 p-4 bg-muted rounded-lg">
                            <div className="flex items-center">
                                <Calendar className="h-5 w-5 text-muted-foreground mr-2" />
                                <h3 className="text-sm font-medium">
                                    Expiry Information
                                </h3>
                            </div>
                            <p className="text-sm text-muted-foreground mt-1">
                                {data.expiry_time === "∞" ?
                                    "This account has no expiration date" :
                                    `Account will expire in: ${data.expiry_time}`
                                }
                            </p>
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
    icon
}: {
    title: string;
    value: string;
    description: string;
    icon?: React.ReactNode;
}) {
    return (
        <div className="border rounded-lg p-4 bg-card shadow-sm hover:shadow-md transition-shadow">
            <div className="flex justify-between items-start mb-2">
                <h3 className="text-sm font-medium text-muted-foreground">{title}</h3>
                {icon}
            </div>
            <p className="text-2xl font-bold">{value}</p>
            <p className="text-sm text-muted-foreground mt-1">{description}</p>
        </div>
    )
}