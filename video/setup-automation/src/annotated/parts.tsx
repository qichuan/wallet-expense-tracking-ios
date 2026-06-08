import React from "react";
import { interpolate, useCurrentFrame, Easing } from "remotion";
import { fontFamily, brand, HIGHLIGHT } from "../theme";

export type ActionType = "tap" | "scroll" | "check" | "type" | "done";

// ---- Action-type glyph shown in the caption strip ----
export const ActionIcon: React.FC<{ type: ActionType; size?: number }> = ({
  type,
  size = 56,
}) => {
  const s = size;
  const stroke = "#fff";
  switch (type) {
    case "scroll":
      return (
        <svg width={s} height={s} viewBox="0 0 48 48" fill="none">
          <path d="M24 6v36" stroke={stroke} strokeWidth={4} strokeLinecap="round" />
          <path d="M14 32l10 10 10-10" stroke={stroke} strokeWidth={4} strokeLinecap="round" strokeLinejoin="round" />
          <path d="M14 16l10-10 10 10" stroke={stroke} strokeWidth={4} strokeLinecap="round" strokeLinejoin="round" opacity={0.55} />
        </svg>
      );
    case "check":
      return (
        <svg width={s} height={s} viewBox="0 0 48 48" fill="none">
          <circle cx="24" cy="24" r="19" stroke={stroke} strokeWidth={4} />
          <path d="M15 24l6 6 12-13" stroke={stroke} strokeWidth={4} strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    case "type":
      return (
        <svg width={s} height={s} viewBox="0 0 48 48" fill="none">
          <rect x="4" y="13" width="40" height="26" rx="4" stroke={stroke} strokeWidth={4} />
          <path d="M12 22h0M20 22h0M28 22h0M36 22h0M12 30h24" stroke={stroke} strokeWidth={4} strokeLinecap="round" />
        </svg>
      );
    case "done":
      return (
        <svg width={s} height={s} viewBox="0 0 48 48" fill="none">
          <circle cx="24" cy="24" r="19" fill={brand.green} />
          <path d="M15 24l6 6 12-13" stroke="#fff" strokeWidth={4} strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    default: // tap
      return (
        <svg width={s} height={s} viewBox="0 0 48 48" fill="none">
          <circle cx="24" cy="24" r="7" fill={stroke} />
          <circle cx="24" cy="24" r="14" stroke={stroke} strokeWidth={3} opacity={0.6} />
          <circle cx="24" cy="24" r="21" stroke={stroke} strokeWidth={3} opacity={0.28} />
        </svg>
      );
  }
};

// ---- A gentle tap pulse placed on the real footage (720x1558 coords) ----
export const FootageTap: React.FC<{ x: number; y: number; at: number }> = ({
  x,
  y,
  at,
}) => {
  const frame = useCurrentFrame();
  const t = frame - at;
  if (t < 0 || t > 26) return null;

  const pulse = interpolate(t, [0, 16], [0.3, 2.1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const pulseOpacity = interpolate(t, [0, 16], [0.75, 0], {
    extrapolateRight: "clamp",
  });
  const dot = interpolate(t, [0, 4, 18, 26], [0, 1, 1, 0], {
    extrapolateRight: "clamp",
  });
  const ring = 110;

  return (
    <div style={{ position: "absolute", left: x, top: y, pointerEvents: "none" }}>
      <div
        style={{
          position: "absolute",
          width: ring,
          height: ring,
          marginLeft: -ring / 2,
          marginTop: -ring / 2,
          borderRadius: "50%",
          border: `6px solid ${HIGHLIGHT}`,
          transform: `scale(${pulse})`,
          opacity: pulseOpacity,
        }}
      />
      <div
        style={{
          position: "absolute",
          width: 46,
          height: 46,
          marginLeft: -23,
          marginTop: -23,
          borderRadius: "50%",
          background: HIGHLIGHT,
          boxShadow: `0 0 22px ${HIGHLIGHT}`,
          opacity: dot,
          transform: `scale(${interpolate(dot, [0, 1], [0.6, 1])})`,
        }}
      />
    </div>
  );
};

// ---- Centered scroll hint (no exact position needed) ----
export const ScrollHint: React.FC = () => {
  const frame = useCurrentFrame();
  const bob = Math.sin((frame / 30) * Math.PI * 2 * 1.1) * 16;
  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        top: 780,
        display: "flex",
        justifyContent: "center",
        pointerEvents: "none",
      }}
    >
      <div
        style={{
          transform: `translateY(${bob}px)`,
          background: "rgba(10,20,40,0.78)",
          border: `2px solid ${HIGHLIGHT}aa`,
          borderRadius: 60,
          padding: "18px 34px",
          display: "flex",
          alignItems: "center",
          gap: 16,
          fontFamily,
          color: "#fff",
          fontSize: 36,
          fontWeight: 600,
          boxShadow: "0 12px 40px rgba(0,0,0,0.5)",
        }}
      >
        <svg width="40" height="40" viewBox="0 0 48 48" fill="none">
          <path d="M24 8v32" stroke={HIGHLIGHT} strokeWidth={5} strokeLinecap="round" />
          <path d="M12 28l12 12 12-12" stroke={HIGHLIGHT} strokeWidth={5} strokeLinecap="round" strokeLinejoin="round" />
        </svg>
        Scroll
      </div>
    </div>
  );
};

// ---- Bottom caption strip ----
export const CaptionStrip: React.FC<{
  num: number;
  total: number;
  text: string;
  action: ActionType;
  top: number;
  height: number;
}> = ({ num, total, text, action, top, height }) => {
  const frame = useCurrentFrame();
  const appear = interpolate(frame, [0, 8], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <div
      style={{
        position: "absolute",
        top,
        left: 0,
        right: 0,
        height,
        background: `linear-gradient(180deg, #0C1830 0%, #0A1428 100%)`,
        borderTop: `2px solid ${brand.accent}`,
        display: "flex",
        alignItems: "center",
        gap: 26,
        padding: "0 36px",
        fontFamily,
        opacity: appear,
      }}
    >
      <div
        style={{
          flexShrink: 0,
          width: 92,
          height: 92,
          borderRadius: "50%",
          background: brand.accent,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          color: "#fff",
          lineHeight: 1,
        }}
      >
        <div style={{ fontSize: 42, fontWeight: 800 }}>{num}</div>
        <div style={{ fontSize: 18, opacity: 0.8, marginTop: 2 }}>/ {total}</div>
      </div>
      <div style={{ flexShrink: 0, opacity: 0.92 }}>
        <ActionIcon type={action} size={58} />
      </div>
      <div style={{ color: "#fff", fontSize: 38, fontWeight: 600, lineHeight: 1.25 }}>
        {text}
      </div>
    </div>
  );
};
