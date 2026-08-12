import Link from "next/link"
import { ChevronRight } from "lucide-react"
import { cn } from "@/lib/cn"

export function AppleLogo({ className = "w-4 h-4" }: { className?: string }) {
  return (
    <svg viewBox="0 0 384 512" fill="currentColor" className={className} aria-hidden="true">
      <path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z" />
    </svg>
  )
}

/**
 * DeskArt's mark: a ring of dots with a few set aside in the corner — the same
 * arrangement the app itself produces, so the logo states what the product does.
 */
export function LogoMark({ className = "w-8 h-8" }: { className?: string }) {
  const ring = Array.from({ length: 10 }, (_, i) => {
    const a = (i / 10) * Math.PI * 2 - Math.PI / 2
    return { cx: 128 + 78 * Math.cos(a), cy: 128 + 78 * Math.sin(a) }
  })
  return (
    <svg viewBox="0 0 256 256" className={className} aria-hidden="true">
      {ring.map((p, i) => (
        <circle key={i} cx={p.cx} cy={p.cy} r={15} fill="currentColor" />
      ))}
      <circle cx={128} cy={128} r={17} fill="currentColor" />
      {[0, 1].map((r) =>
        [0, 1].map((c) => (
          <circle
            key={`${r}-${c}`}
            cx={214 - c * 34}
            cy={214 - r * 34}
            r={10}
            fill="currentColor"
            opacity={0.32}
          />
        )),
      )}
    </svg>
  )
}

/** Primary call to action. The one place the page spends its accent. */
export function AppleButton({
  label = "Download DeskArt",
  href,
  full = false,
  className,
}: {
  label?: string
  href: string
  full?: boolean
  className?: string
}) {
  return (
    <Link
      href={href}
      className={cn(
        "group inline-flex items-center justify-center gap-2 rounded-full bg-white",
        "px-5 py-3 text-sm font-medium text-black transition-all",
        "hover:bg-white/90 active:scale-[0.98]",
        full && "w-full",
        className,
      )}
    >
      <AppleLogo className="h-4 w-4" />
      {label}
      <ChevronRight className="h-4 w-4 transition-transform group-hover:translate-x-px" />
    </Link>
  )
}

/** Secondary action: outlined, so it never competes with the download. */
export function GhostButton({
  children,
  href,
  className,
}: {
  children: React.ReactNode
  href: string
  className?: string
}) {
  return (
    <Link
      href={href}
      className={cn(
        "group inline-flex items-center justify-center gap-2 rounded-full",
        "border border-white/15 px-5 py-3 text-sm font-medium text-white",
        "transition-all hover:bg-white/5 active:scale-[0.98]",
        className,
      )}
    >
      {children}
      <ChevronRight className="h-4 w-4 transition-transform group-hover:translate-x-px" />
    </Link>
  )
}

export function SectionEyebrow({ label, tag }: { label: string; tag?: string }) {
  return (
    <div className="flex items-center gap-2.5 text-sm">
      <span className="h-1.5 w-1.5 rounded-full bg-white" />
      <span className="font-medium text-white">{label}</span>
      {tag && (
        <span className="rounded-full border border-white/10 px-2 py-0.5 text-white/50">
          {tag}
        </span>
      )}
    </div>
  )
}

/**
 * Gradient fill for the headline's emphasised word.
 *
 * The darkest stops are lifted well above the page background. A ramp that
 * bottoms out near #091020 leaves the word effectively invisible for a large
 * part of the 6s sweep, since those stops sit on top of a #0c0c0c canvas —
 * the shine should travel across the word, not erase it.
 */
export const gradientStyle: React.CSSProperties = {
  backgroundImage:
    "linear-gradient(to right, #4a7fb5 0%, #6aa8d8 12.5%, #A4F4FD 32.5%, #00d2ff 50%, #7fc4e8 67.5%, #4a7fb5 87.5%, #4a7fb5 100%)",
  backgroundSize: "200% auto",
  WebkitBackgroundClip: "text",
  backgroundClip: "text",
  color: "transparent",
  WebkitTextFillColor: "transparent",
  filter: "url(#c3-noise)",
}
