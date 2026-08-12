import { AppMockup } from "@/components/AppMockup"
import { Features } from "@/components/Features"
import { FinalCTA } from "@/components/FinalCTA"
import { Hero } from "@/components/Hero"
import { Install } from "@/components/Install"
import { MenuBarStrip } from "@/components/MenuBarStrip"
import { Nav } from "@/components/Nav"
import { ShapeGallery } from "@/components/ShapeGallery"
import { LogoMark } from "@/components/primitives"
import { AUTHOR, LICENSE, RELEASES, REPO } from "@/lib/links"
import Link from "next/link"

export default function Home() {
  return (
    <div className="relative min-h-dvh overflow-x-hidden bg-[#0c0c0c] text-white">
      {/* Grain filter used by the shiny headline. */}
      <svg className="pointer-events-none absolute h-0 w-0" aria-hidden="true">
        <filter id="c3-noise">
          <feTurbulence
            type="fractalNoise"
            baseFrequency="0.9"
            numOctaves="2"
            stitchTiles="stitch"
          />
          <feColorMatrix
            type="matrix"
            values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.35 0"
          />
          <feComposite in2="SourceGraphic" operator="in" result="noise" />
          <feBlend in="SourceGraphic" in2="noise" mode="multiply" />
        </filter>
      </svg>

      {/* Ambient backdrop. A pair of soft radial washes rather than a video:
          a fullscreen loop costs megabytes and burns battery on a page whose
          whole subject is a static grid of dots. */}
      <div className="pointer-events-none fixed inset-0 z-0" aria-hidden="true">
        <div
          className="absolute inset-0"
          style={{
            background:
              "radial-gradient(900px circle at 50% -10%, rgba(61,129,227,0.16), transparent 60%)," +
              "radial-gradient(700px circle at 85% 15%, rgba(0,210,255,0.08), transparent 55%)," +
              "radial-gradient(800px circle at 10% 40%, rgba(164,244,253,0.05), transparent 60%)",
          }}
        />
        {/* Faint dot lattice — the grid DeskArt arranges icons on. */}
        <div
          className="absolute inset-0 opacity-[0.05]"
          style={{
            backgroundImage: "radial-gradient(circle, #fff 1px, transparent 1px)",
            backgroundSize: "34px 34px",
          }}
        />
      </div>

      {/* Container guide lines, echoing the app's own alignment grid. */}
      <div
        aria-hidden="true"
        className="pointer-events-none fixed inset-y-0 left-1/2 z-[5] hidden w-px -translate-x-[calc(50%+36rem)] bg-white/10 md:block"
      />
      <div
        aria-hidden="true"
        className="pointer-events-none fixed inset-y-0 left-1/2 z-[5] hidden w-px translate-x-[calc(-50%+36rem)] bg-white/10 md:block"
      />

      <Nav />
      <Hero />
      <MenuBarStrip />
      <AppMockup />
      <Features />
      <ShapeGallery />
      <Install />
      <FinalCTA />

      <footer className="relative z-10 border-t border-white/10">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-4 px-6 py-8 text-sm text-white/50">
          <LogoMark className="h-5 w-5 text-white/40" />
          <span>
            Built by{" "}
            <Link href={AUTHOR} className="text-white/70 transition-colors hover:text-white">
              Firas Latrach
            </Link>
          </span>
          <div className="ml-auto flex gap-6">
            <Link href={REPO} className="transition-colors hover:text-white">
              GitHub
            </Link>
            <Link href={RELEASES} className="transition-colors hover:text-white">
              Releases
            </Link>
            <Link href={LICENSE} className="transition-colors hover:text-white">
              MIT
            </Link>
          </div>
        </div>
      </footer>
    </div>
  )
}
