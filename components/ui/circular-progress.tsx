"use client"

import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

export interface Segment {
  value: number
  color: string
  label?: string
  gradient?: string
}

const circularProgressVariants = cva("relative inline-grid place-items-center", {
  variants: {
    size: {
      xs: "size-12",
      sm: "size-16",
      default: "size-24",
      lg: "size-32",
      xl: "size-60",
    },
  },
  defaultVariants: {
    size: "default",
  },
})

const Tooltip = ({
  children,
  content,
  disabled,
  position = "top",
}: {
  children: React.ReactNode
  content: string
  disabled?: boolean
  position?: "top" | "bottom" | "left" | "right"
}) => {
  const [isVisible, setIsVisible] = React.useState(false)

  if (disabled) return <>{children}</>

  const positionClasses = {
    top: "bottom-full left-1/2 transform -translate-x-1/2 mb-2",
    bottom: "top-full left-1/2 transform -translate-x-1/2 mt-2",
    left: "right-full top-1/2 transform -translate-y-1/2 mr-2",
    right: "left-full top-1/2 transform -translate-y-1/2 ml-2",
  }

  const arrowClasses = {
    top: "absolute top-full left-1/2 transform -translate-x-1/2 border-4 border-transparent border-t-gray-900 dark:border-t-gray-700",
    bottom:
      "absolute bottom-full left-1/2 transform -translate-x-1/2 border-4 border-transparent border-b-gray-900 dark:border-b-gray-700",
    left: "absolute left-full top-1/2 transform -translate-y-1/2 border-4 border-transparent border-l-gray-900 dark:border-l-gray-700",
    right:
      "absolute right-full top-1/2 transform -translate-y-1/2 border-4 border-transparent border-r-gray-900 dark:border-r-gray-700",
  }

  return (
    <div className="relative inline-block">
      <div onMouseEnter={() => setIsVisible(true)} onMouseLeave={() => setIsVisible(false)} className="cursor-help">
        {children}
      </div>
      {isVisible && (
        <div
          className={cn(
            "absolute px-2 py-1 text-xs text-white bg-gray-900 dark:bg-gray-700 rounded shadow-lg whitespace-nowrap z-50",
            positionClasses[position],
          )}
        >
          {content}
          <div className={arrowClasses[position]}></div>
        </div>
      )}
    </div>
  )
}

const Legend = ({ segments, className }: { segments: Segment[]; className?: string }) => {
  return (
    <div className={cn("flex flex-wrap gap-2 text-sm", className)}>
      {segments.map((segment, index) => (
        <div key={index} className="flex items-center gap-1.5">
          <div
            className={cn("w-3 h-3 rounded-full flex-shrink-0", segment.color)}
            style={segment.gradient ? { background: segment.gradient } : undefined}
          />
          <span className="text-foreground truncate">
            {segment.label || `Segment ${index + 1}`}: {segment.value}
          </span>
        </div>
      ))}
    </div>
  )
}

interface CircularProgressProps
  extends Omit<React.HTMLAttributes<HTMLDivElement>, "children">,
  VariantProps<typeof circularProgressVariants> {
  segments?: Segment[]
  value?: number // Single value mode
  max?: number
  total?: number // Legacy prop, use max instead
  thickness?: number
  showLabel?: boolean
  label?: React.ReactNode
  roundStroke?: boolean
  indeterminate?: boolean
  animated?: boolean
  trackColor?: string
  formatLabel?: (value: number, max: number) => React.ReactNode
  showPercentage?: boolean
  direction?: "clockwise" | "counterclockwise"
  showTooltips?: boolean
  showLegend?: boolean
  legendPosition?: "top" | "bottom" | "left" | "right"
  legendClassName?: string
}

const CircularProgress = React.forwardRef<HTMLDivElement, CircularProgressProps>((
  {
    segments,
    value,
    max: maxProp,
    total, // Legacy support
    size = "default",
    thickness = 8,
    roundStroke = true,
    showLabel = true,
    label,
    indeterminate = false,
    animated = true,
    trackColor = "text-muted-foreground/20 dark:text-muted-foreground/10",
    formatLabel,
    showPercentage = false,
    direction = "clockwise",
    showTooltips = true,
    showLegend = false,
    legendPosition = "bottom",
    legendClassName,
    className,
    ...props
  },
  ref
) => {
  const sizeMap = {
    xs: 48,
    sm: 64,
    default: 96,
    lg: 128,
    xl: 160,
  }

  const dimension = sizeMap[size || "default"]

  const minRadius = Math.max(12, dimension * 0.2) // Minimum radius to prevent cramping
  const maxRadius = dimension * 0.45 // Maximum radius
  const calculatedRadius = (dimension - thickness) / 2
  const radius = Math.max(minRadius, Math.min(maxRadius, calculatedRadius))

  const circumference = 2 * Math.PI * radius

  const max = maxProp || total || 100
  const isMultiSegment = segments && segments.length > 0
  const totalValue = isMultiSegment ? segments.reduce((sum, s) => sum + s.value, 0) : value || 0

  const normalizedValue = Math.min(Math.max(totalValue, 0), max)
  const percentage = max > 0 ? (normalizedValue / max) * 100 : 0

  const rotationClass = direction === "counterclockwise" ? "scale-x-[-1]" : ""
  const indeterminateClass = indeterminate ? "animate-spin" : ""

  const sortedSegments = React.useMemo(() => {
    if (!isMultiSegment) return []
    return [...segments].sort((a, b) => b.value - a.value)
  }, [segments, isMultiSegment])

  const defaultFormatLabel = React.useCallback(
    (val: number, maxVal: number) => {
      if (showPercentage) {
        return `${Math.round((val / maxVal) * 100)}%`
      }
      return maxVal === 100 ? `${val.toFixed(1)}` : `${val.toFixed(1)} / ${maxVal}`
    },
    [showPercentage],
  )

  const displayLabel = React.useMemo(() => {
    if (label) return label
    if (formatLabel) return formatLabel(normalizedValue, max)
    return defaultFormatLabel(normalizedValue, max)
  }, [label, formatLabel, normalizedValue, max, defaultFormatLabel])

  const [hoveredSegment, setHoveredSegment] = React.useState<number | null>(null)

  const progressComponent = (
    <div
      ref={ref}
      role="progressbar"
      aria-valuemin={0}
      aria-valuemax={max}
      aria-valuenow={normalizedValue}
      aria-label={typeof displayLabel === "string" ? displayLabel : `Progress: ${percentage.toFixed(1)}%`}
      className={cn(circularProgressVariants({ size }), className)}
      {...props}
    >
      <svg
        width={dimension}
        height={dimension}
        viewBox={`0 0 ${dimension} ${dimension}`}
        className={cn("size-full", rotationClass, indeterminate && indeterminateClass)}
      >
        {/* Background track */}
        <circle
          cx={dimension / 2}
          cy={dimension / 2}
          r={radius}
          stroke="currentColor"
          strokeWidth={thickness}
          className={trackColor}
          fill="none"
        />

        {/* Progress segments or single progress */}
        {isMultiSegment ? (
          <>
            {sortedSegments.map((segment) => {
              const originalIndex = segments.findIndex((s) => s === segment)
              const fraction = segment.value / max
              const length = circumference * fraction
              const dasharray = `${length} ${circumference - length}`

              // Calculate offset based on original segment order for proper positioning
              let currentOffset = 0
              for (let j = 0; j < originalIndex; j++) {
                currentOffset += (circumference * segments[j].value) / max
              }
              const dashoffset = -currentOffset

              return (
                <g key={`segment-${originalIndex}`}>
                  <circle
                    cx={dimension / 2}
                    cy={dimension / 2}
                    r={radius}
                    stroke={segment.gradient ? "url(#gradient-" + originalIndex + ")" : "currentColor"}
                    strokeWidth={thickness}
                    strokeLinecap={roundStroke ? "round" : "butt"}
                    strokeDasharray={dasharray}
                    strokeDashoffset={dashoffset}
                    className={cn(
                      !segment.gradient && segment.color,
                      animated && "transition-all duration-500 ease-out",
                      showTooltips && "cursor-help",
                      hoveredSegment === originalIndex && "opacity-80",
                    )}
                    fill="none"
                    transform={`rotate(-90 ${dimension / 2} ${dimension / 2})`}
                    onMouseEnter={() => showTooltips && setHoveredSegment(originalIndex)}
                    onMouseLeave={() => showTooltips && setHoveredSegment(null)}
                  />
                  {segment.gradient && (
                    <defs>
                      <linearGradient id={`gradient-${originalIndex}`} x1="0%" y1="0%" x2="100%" y2="0%">
                        <stop offset="0%" style={{ stopColor: segment.gradient.split(",")[0] || segment.color }} />
                        <stop offset="100%" style={{ stopColor: segment.gradient.split(",")[1] || segment.color }} />
                      </linearGradient>
                    </defs>
                  )}
                </g>
              )
            })}
          </>
        ) : (
          // Single value mode
          <circle
            cx={dimension / 2}
            cy={dimension / 2}
            r={radius}
            stroke="currentColor"
            strokeWidth={thickness}
            strokeLinecap={roundStroke ? "round" : "butt"}
            strokeDasharray={circumference}
            strokeDashoffset={circumference - (circumference * normalizedValue) / max}
            className={cn("text-primary", animated && "transition-all duration-500 ease-out")}
            fill="none"
            transform={`rotate(-90 ${dimension / 2} ${dimension / 2})`}
          />
        )}
      </svg>

      {showTooltips && hoveredSegment !== null && isMultiSegment && (
        <div className="absolute inset-0 pointer-events-none">
          <Tooltip
            content={`${segments[hoveredSegment].label || `Segment ${hoveredSegment + 1}`}: ${segments[hoveredSegment].value} (${((segments[hoveredSegment].value / max) * 100).toFixed(1)}%)`}
            disabled={false}
            position="top"
          >
            <div className="w-full h-full" />
          </Tooltip>
        </div>
      )}

      {showLabel && !indeterminate && (
        <div className="absolute flex flex-col items-center justify-center text-center px-2">
          <span
            className={cn(
              "font-medium tabular-nums text-foreground leading-tight break-words", // Added break-words for long labels
              size === "xs" && "text-xs",
              size === "sm" && "text-sm",
              size === "default" && "text-sm",
              size === "lg" && "text-base",
              size === "xl" && "text-lg",
            )}
          >
            {displayLabel}
          </span>
        </div>
      )}

      {indeterminate && showLabel && (
        <div className="absolute flex items-center justify-center">
          <div
            className={cn(
              "animate-pulse text-muted-foreground",
              size === "xs" && "text-xs",
              size === "sm" && "text-sm",
              size === "default" && "text-sm",
              size === "lg" && "text-base",
              size === "xl" && "text-lg",
            )}
          >
            Loading...
          </div>
        </div>
      )}
    </div>
  )

  if (!showLegend || !isMultiSegment) {
    return progressComponent
  }

  const legendComponent = (
    <Legend
      segments={segments}
      className={cn(
        "max-w-sm", // Responsive width constraint
        legendClassName,
      )}
    />
  )

  switch (legendPosition) {
    case "top":
      return (
        <div className="flex flex-col items-center gap-2 sm:gap-4">
          {legendComponent}
          {progressComponent}
        </div>
      )
    case "left":
      return (
        <div className="flex flex-col sm:flex-row items-center gap-2 sm:gap-4 lg:gap-6">
          <div className="flex-shrink-0">{legendComponent}</div>
          {progressComponent}
        </div>
      )
    case "right":
      return (
        <div className="flex flex-col sm:flex-row items-center gap-2 sm:gap-4 lg:gap-6">
          {progressComponent}
          <div className="flex-shrink-0">{legendComponent}</div>
        </div>
      )
    case "bottom":
    default:
      return (
        <div className="flex flex-col items-center gap-2 sm:gap-4">
          {progressComponent}
          {legendComponent}
        </div>
      )
  }
})
CircularProgress.displayName = "CircularProgress"

const CircularProgressSimple = React.forwardRef<
  HTMLDivElement,
  Omit<CircularProgressProps, "segments"> & { value: number }
>(({ value, ...props }, ref) => <CircularProgress ref={ref} value={value} {...props} />)
CircularProgressSimple.displayName = "CircularProgressSimple"

const CircularProgressIndeterminate = React.forwardRef<
  HTMLDivElement,
  Omit<CircularProgressProps, "value" | "segments" | "indeterminate">
>((props, ref) => <CircularProgress ref={ref} indeterminate {...props} />)
CircularProgressIndeterminate.displayName = "CircularProgressIndeterminate"

export { CircularProgress, CircularProgressSimple, CircularProgressIndeterminate, Legend, type CircularProgressProps }