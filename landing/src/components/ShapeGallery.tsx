"use client"

import { motion } from "motion/react"
import { SHAPES } from "@/lib/shapes"
import { label } from "./AppMockup"

const ORDER = [
  "text", "heart", "star", "spiral", "infinity", "smiley", "flower", "circle",
  "butterfly", "arrow", "diamond", "wave", "ring", "scatter", "grid",
].filter((k) => SHAPES[k])

export function ShapeGallery() {
  return (
    <section id="shapes" className="relative z-10 mx-auto max-w-6xl px-6 py-20 md:py-28">
      <div className="text-center">
        <h2 className="text-3xl leading-[1.02] font-semibold tracking-tight text-balance md:text-5xl">
          Fifteen shapes
        </h2>
        <p className="mx-auto mt-5 max-w-md text-base leading-[1.6] text-pretty text-white/60">
          Every one drawn here with the app&rsquo;s real geometry — the same points
          it will place your icons on.
        </p>
      </div>

      <div className="mt-12 grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
        {ORDER.map((k, i) => {
          const d = SHAPES[k]
          return (
            <motion.div
              key={k}
              initial={{ opacity: 0, y: 14 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.3 }}
              transition={{
                duration: 0.5,
                delay: Math.min(i * 0.04, 0.4),
                ease: "easeOut",
              }}
              className="liquid-glass rounded-xl p-4 text-center"
            >
              <svg
                viewBox="0 0 100 100"
                role="img"
                aria-label={`${label(k)}, ${d.count} icons`}
                className="block w-full"
              >
                {d.points.map(([x, y], j) => (
                  <circle
                    key={j}
                    cx={8 + x * 84}
                    cy={8 + y * 84}
                    r={2.7}
                    fill="#4ec5f4"
                  />
                ))}
              </svg>
              <div className="mt-2.5 text-[13px] font-medium">{label(k)}</div>
              <div className="text-[11px] tabular-nums text-white/40">
                {d.count} icons
              </div>
            </motion.div>
          )
        })}
      </div>
    </section>
  )
}
