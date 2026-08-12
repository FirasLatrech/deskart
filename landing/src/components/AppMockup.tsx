"use client"

import { useCallback, useEffect, useRef, useState } from "react"
import { motion } from "motion/react"
import { Camera, Clock, Dices, RotateCcw, Sparkles, Wand2 } from "lucide-react"
import { SHAPES } from "@/lib/shapes"
import { cn } from "@/lib/cn"

const ORDER = [
  "text", "heart", "star", "spiral", "infinity", "smiley", "flower", "circle",
  "butterfly", "arrow", "diamond", "wave", "ring", "scatter", "grid",
].filter((k) => SHAPES[k])

/** Shapes the mockup cycles through unattended — the most recognisable ones. */
const TOUR = ["text", "heart", "star", "infinity", "smiley", "spiral"]

const LABELS: Record<string, string> = { text: 'Text "HI"', ring: "Double ring" }
export const label = (k: string) => LABELS[k] ?? k[0].toUpperCase() + k.slice(1)

const FAMILY: Record<string, string> = {
  text: "Typographic",
  circle: "Classic", grid: "Classic", diamond: "Classic", ring: "Classic",
  star: "Playful", smiley: "Playful", arrow: "Playful", infinity: "Playful", heart: "Playful",
  flower: "Organic", wave: "Organic", spiral: "Organic", butterfly: "Organic", scatter: "Organic",
}

const VB = { w: 480, h: 300, pad: 30 }

export function AppMockup() {
  const [active, setActive] = useState("text")
  const [touring, setTouring] = useState(true)
  const tourIndex = useRef(0)
  const rootRef = useRef<HTMLDivElement>(null)
  const [visible, setVisible] = useState(false)

  const pick = useCallback((k: string) => {
    setTouring(false) // any interaction ends the tour for good
    setActive(k)
  }, [])

  // Only animate while on screen — a looping animation in an off-screen
  // section is wasted compositing.
  useEffect(() => {
    const el = rootRef.current
    if (!el) return
    const io = new IntersectionObserver(([e]) => setVisible(e.isIntersecting), {
      threshold: 0.25,
    })
    io.observe(el)
    return () => io.disconnect()
  }, [])

  useEffect(() => {
    if (!touring || !visible) return
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    const id = setInterval(() => {
      if (document.hidden) return
      tourIndex.current = (tourIndex.current + 1) % TOUR.length
      setActive(TOUR[tourIndex.current])
    }, 2800)
    return () => clearInterval(id)
  }, [touring, visible])

  const data = SHAPES[active]
  const box = Math.min(VB.w, VB.h) - VB.pad * 2
  const offX = (VB.w - box) / 2
  const offY = (VB.h - box) / 2

  return (
    <section className="relative z-10 mx-auto max-w-6xl px-6 py-16 md:py-24">
      <motion.div
        ref={rootRef}
        initial={{ opacity: 0, y: 40 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.2 }}
        transition={{ duration: 0.8, delay: 0.1, ease: [0.22, 1, 0.36, 1] }}
        className="relative overflow-hidden rounded-2xl border border-white/10 bg-[#0e1014]/90 backdrop-blur-2xl"
      >
        {/* Title bar */}
        <div className="flex items-center border-b border-white/10 px-4 py-3">
          <div className="flex gap-2">
            <span className="h-3 w-3 rounded-full bg-[#ff5f57]" />
            <span className="h-3 w-3 rounded-full bg-[#febc2e]" />
            <span className="h-3 w-3 rounded-full bg-[#28c840]" />
          </div>
          <span className="mx-auto text-xs text-white/50">DeskArt — Desktop</span>
        </div>

        <div className="grid grid-cols-12">
          {/* The app's menu panel, reproduced */}
          <aside className="col-span-12 border-white/10 bg-black/30 p-4 md:col-span-4 md:border-r lg:col-span-3">
            <div className="mb-4 flex items-center gap-2">
              <Sparkles className="h-4 w-4 text-[#A4F4FD]" />
              <span className="text-sm font-semibold">DeskArt</span>
              <span className="ml-auto rounded-full bg-white/10 px-2 py-0.5 text-[11px] tabular-nums text-white/60">
                46 icons
              </span>
            </div>

            <div className="space-y-3">
              <div>
                <span className="text-[11px] tracking-wide text-white/40 uppercase">
                  Shape
                </span>
                <div className="mt-1.5 flex items-center gap-2">
                  <div className="flex flex-1 items-center justify-between rounded-lg border border-white/10 bg-white/[0.04] px-3 py-2 text-[13px]">
                    <span>{label(active)}</span>
                    <span className="text-white/40">⌄</span>
                  </div>
                  <button
                    type="button"
                    onClick={() => pick(TOUR[(tourIndex.current += 1) % TOUR.length])}
                    aria-label="Pick a random shape"
                    className="flex h-9 w-9 items-center justify-center rounded-lg border border-white/10 text-white/60 transition-colors hover:text-white"
                  >
                    <Dices className="h-4 w-4" />
                  </button>
                </div>
              </div>

              <div>
                <span className="text-[11px] tracking-wide text-white/40 uppercase">
                  Display
                </span>
                <div className="mt-1.5 flex items-center justify-between rounded-lg border border-white/10 bg-white/[0.04] px-3 py-2 text-[13px]">
                  <span className="truncate">Built-in Retina Display</span>
                  <span className="text-white/40">⌄</span>
                </div>
              </div>
            </div>

            <div className="mt-4 flex items-center gap-2">
              <span className="flex flex-1 items-center justify-center gap-2 rounded-lg bg-[#4ec5f4] px-3 py-2 text-[13px] font-semibold text-[#04202c]">
                <Wand2 className="h-3.5 w-3.5" />
                Arrange
              </span>
              <span className="flex h-9 w-9 items-center justify-center rounded-lg text-white/50">
                <Camera className="h-4 w-4" />
              </span>
              <span className="flex h-9 w-9 items-center justify-center rounded-lg text-white/50">
                <Clock className="h-4 w-4" />
              </span>
            </div>

            <div className="mt-3 flex items-center gap-1.5 text-[11px] text-white/50">
              <RotateCcw className="h-3 w-3" />
              Undo — Before {label(active)}
            </div>

            <p className="mt-4 border-t border-white/10 pt-3 text-[11px] leading-relaxed text-white/40">
              {data.count} icons in shape
              {46 - data.count > 0 && ` · ${46 - data.count} parked`}
            </p>
          </aside>

          {/* Preview canvas */}
          <div className="col-span-12 md:col-span-8 lg:col-span-9">
            <svg
              viewBox={`0 0 ${VB.w} ${VB.h}`}
              preserveAspectRatio="xMidYMid meet"
              role="img"
              aria-label={`Desktop icons arranged into ${label(active)}, ${data.count} icons`}
              className="block h-[240px] w-full bg-[#070809] sm:h-[300px] lg:h-[360px]"
            >
              {data.points.map(([x, y], i) => (
                <circle
                  // Keying by index lets a dot transition from one position to
                  // the next instead of the set being torn down, so switching
                  // shapes reads as a rearrangement.
                  key={i}
                  cx={offX + x * box}
                  cy={offY + y * box}
                  r={5.2}
                  fill="#4ec5f4"
                  style={{
                    transition:
                      "cx 600ms cubic-bezier(0.22,1,0.36,1), cy 600ms cubic-bezier(0.22,1,0.36,1)",
                    transitionDelay: `${Math.min(i * 9, 260)}ms`,
                  }}
                />
              ))}
            </svg>

            <div
              role="group"
              aria-label="Choose a shape to preview"
              className="flex flex-wrap justify-center gap-2 border-t border-white/10 bg-black/20 p-3.5"
            >
              {ORDER.map((k) => {
                const on = k === active
                return (
                  <button
                    key={k}
                    type="button"
                    onClick={() => pick(k)}
                    aria-pressed={on}
                    title={FAMILY[k]}
                    className={cn(
                      "cursor-pointer rounded-full border px-3.5 py-1.5 text-[13px]",
                      "transition-colors duration-150 ease-out",
                      on
                        ? "border-[#1d6a8a] bg-[#4ec5f4]/15 text-[#4ec5f4]"
                        : "border-white/10 bg-white/[0.03] text-white/60 hover:border-white/20 hover:text-white",
                    )}
                  >
                    {label(k)}
                  </button>
                )
              })}
            </div>
          </div>
        </div>
      </motion.div>

      <p className="mt-4 text-center text-xs text-white/40">
        Real layouts, generated by the app&rsquo;s own placement engine.
      </p>
    </section>
  )
}
