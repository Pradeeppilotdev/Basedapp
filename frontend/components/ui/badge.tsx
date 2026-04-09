import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"

import { cn } from "@/lib/utils"

const badgeVariants = cva(
  "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
  {
    variants: {
      variant: {
        default:
          "border-transparent bg-gradient-to-r from-purple-600 to-cyan-600 text-white shadow-lg shadow-purple-500/30",
        secondary:
          "border-purple-500/30 bg-purple-500/10 text-purple-300",
        destructive:
          "border-transparent bg-red-500 text-white",
        outline: "border-purple-500/50 text-purple-300",
        success: "border-transparent bg-gradient-to-r from-green-600 to-emerald-600 text-white shadow-lg shadow-green-500/30",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
)

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return (
    <div className={cn(badgeVariants({ variant }), className)} {...props} />
  )
}

export { Badge, badgeVariants }
