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

export const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const pop = spring({ frame, fps, config: { damping: 12, mass: 0.7 } });
  const checkLen = interpolate(frame, [6, 24], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  const titleOpacity = interpolate(frame, [18, 34], [0, 1], {
    extrapolateRight: "clamp",
  });
  const subOpacity = interpolate(frame, [30, 48], [0, 1], {
    extrapolateRight: "clamp",
  });

  const ring = 280;
  const dash = 300;

  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(120% 90% at 50% 22%, #133e2b 0%, ${brand.bgPrimary} 60%, #05070f 100%)`,
        fontFamily,
        alignItems: "center",
        justifyContent: "center",
        padding: 80,
      }}
    >
      <div
        style={{
          transform: `scale(${pop})`,
          width: ring,
          height: ring,
          borderRadius: "50%",
          background: `linear-gradient(150deg,${brand.green},#16a34a)`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: `0 30px 90px ${brand.green}55`,
          marginBottom: 70,
        }}
      >
        <svg width="160" height="160" viewBox="0 0 100 100" fill="none">
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

      <div
        style={{
          opacity: titleOpacity,
          color: "#fff",
          fontSize: 90,
          fontWeight: 800,
          textAlign: "center",
        }}
      >
        You're all set!
      </div>
      <div
        style={{
          opacity: subOpacity,
          color: "rgba(255,255,255,0.72)",
          fontSize: 44,
          fontWeight: 500,
          textAlign: "center",
          marginTop: 34,
          maxWidth: 860,
          lineHeight: 1.4,
        }}
      >
        Every Apple Wallet tap is now logged automatically in CardPulse.
      </div>
    </AbsoluteFill>
  );
};
