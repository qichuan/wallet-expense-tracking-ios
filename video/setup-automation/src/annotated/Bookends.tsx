import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from "remotion";
import { fontFamily, brand } from "../theme";

export const IntroCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const logoIn = spring({ frame, fps, config: { damping: 14, mass: 0.8 } });
  const titleOpacity = interpolate(frame, [8, 22], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const out = interpolate(frame, [durationInFrames - 8, durationInFrames], [1, 0], {
    extrapolateLeft: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(120% 90% at 50% 22%, #16315e 0%, ${brand.bgPrimary} 60%, #05070f 100%)`,
        fontFamily,
        alignItems: "center",
        justifyContent: "center",
        padding: 70,
        opacity: out,
      }}
    >
      <div
        style={{
          transform: `scale(${interpolate(logoIn, [0, 1], [0.4, 1])})`,
          opacity: logoIn,
          width: 200,
          height: 200,
          borderRadius: 52,
          background: `linear-gradient(150deg, ${brand.accent}, #6E9BFF)`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: `0 24px 70px ${brand.accent}66`,
          marginBottom: 56,
        }}
      >
        <svg width="120" height="120" viewBox="0 0 100 100" fill="none">
          <path d="M6 56h16l10-30 16 50 12-34 8 16h20" stroke="#fff" strokeWidth={7} strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </div>
      <div
        style={{
          opacity: titleOpacity,
          color: "#fff",
          fontSize: 70,
          fontWeight: 800,
          textAlign: "center",
          lineHeight: 1.08,
        }}
      >
        Set Up Auto-Tracking
      </div>
      <div
        style={{
          opacity: titleOpacity,
          color: "rgba(255,255,255,0.7)",
          fontSize: 36,
          fontWeight: 500,
          textAlign: "center",
          marginTop: 26,
          maxWidth: 600,
          lineHeight: 1.35,
        }}
      >
        A quick walk-through in the Shortcuts app
      </div>
    </AbsoluteFill>
  );
};

export const OutroCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame, fps, config: { damping: 12, mass: 0.7 } });
  const checkLen = interpolate(frame, [6, 22], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const inFade = interpolate(frame, [0, 8], [0, 1], { extrapolateRight: "clamp" });
  const titleOpacity = interpolate(frame, [16, 30], [0, 1], { extrapolateRight: "clamp" });
  const dash = 300;

  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(120% 90% at 50% 24%, #133e2b 0%, ${brand.bgPrimary} 60%, #05070f 100%)`,
        fontFamily,
        alignItems: "center",
        justifyContent: "center",
        padding: 70,
        opacity: inFade,
      }}
    >
      <div
        style={{
          transform: `scale(${pop})`,
          width: 210,
          height: 210,
          borderRadius: "50%",
          background: `linear-gradient(150deg,${brand.green},#16a34a)`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: `0 24px 70px ${brand.green}55`,
          marginBottom: 56,
        }}
      >
        <svg width="120" height="120" viewBox="0 0 100 100" fill="none">
          <path
            d="M22 52l18 18 38-42"
            stroke="#fff"
            strokeWidth={11}
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeDasharray={dash}
            strokeDashoffset={dash * (1 - checkLen)}
          />
        </svg>
      </div>
      <div style={{ opacity: titleOpacity, color: "#fff", fontSize: 72, fontWeight: 800, textAlign: "center" }}>
        You're all set!
      </div>
      <div
        style={{
          opacity: titleOpacity,
          color: "rgba(255,255,255,0.72)",
          fontSize: 36,
          fontWeight: 500,
          textAlign: "center",
          marginTop: 26,
          maxWidth: 620,
          lineHeight: 1.4,
        }}
      >
        Tap-to-pay Apple Pay transactions are now tracked automatically
      </div>
    </AbsoluteFill>
  );
};
