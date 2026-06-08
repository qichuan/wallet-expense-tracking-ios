import React from "react";
import { fontFamily, ios } from "../theme";

export const Screen: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => (
  <div
    style={{
      position: "absolute",
      inset: 0,
      background: ios.bg,
      fontFamily,
      overflow: "hidden",
    }}
  >
    {children}
  </div>
);

// iOS large-title / nav bar
export const NavBar: React.FC<{
  title: string;
  large?: boolean;
  back?: string;
  trailing?: React.ReactNode;
  top?: number;
}> = ({ title, large, back, trailing, top = 110 }) => (
  <div
    style={{
      position: "absolute",
      top,
      left: 0,
      right: 0,
      padding: "0 56px",
      color: ios.textPrimary,
    }}
  >
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        height: 80,
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        {back ? (
          <div
            style={{
              display: "flex",
              alignItems: "center",
              color: ios.blue,
              fontSize: 38,
            }}
          >
            <svg width="26" height="44" viewBox="0 0 26 44" fill="none">
              <path
                d="M22 6 8 22l14 16"
                stroke={ios.blue}
                strokeWidth={5}
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <span style={{ marginLeft: 6 }}>{back}</span>
          </div>
        ) : null}
      </div>
      {trailing}
    </div>
    {large ? (
      <div style={{ fontSize: 66, fontWeight: 800, marginTop: 6 }}>{title}</div>
    ) : (
      <div
        style={{
          position: "absolute",
          top,
          left: 0,
          right: 0,
          textAlign: "center",
          fontSize: 38,
          fontWeight: 700,
          height: 80,
          lineHeight: "80px",
          pointerEvents: "none",
        }}
      >
        {title}
      </div>
    )}
  </div>
);

export const AppIcon: React.FC<{
  size: number;
  radius?: number;
  gradient: string;
  children?: React.ReactNode;
}> = ({ size, radius, gradient, children }) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: radius ?? size * 0.235,
      background: gradient,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      overflow: "hidden",
    }}
  >
    {children}
  </div>
);

export const Group: React.FC<{
  style?: React.CSSProperties;
  children: React.ReactNode;
}> = ({ style, children }) => (
  <div
    style={{
      background: ios.groupBg,
      borderRadius: 28,
      overflow: "hidden",
      ...style,
    }}
  >
    {children}
  </div>
);

export const Row: React.FC<{
  icon?: React.ReactNode;
  title: React.ReactNode;
  subtitle?: string;
  trailing?: React.ReactNode;
  divider?: boolean;
  height?: number;
}> = ({ icon, title, subtitle, trailing, divider = true, height = 120 }) => (
  <div
    style={{
      display: "flex",
      alignItems: "center",
      minHeight: height,
      padding: "0 32px",
      gap: 28,
      position: "relative",
    }}
  >
    {icon}
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ color: ios.textPrimary, fontSize: 38, fontWeight: 500 }}>
        {title}
      </div>
      {subtitle ? (
        <div
          style={{
            color: ios.textSecondary,
            fontSize: 28,
            marginTop: 6,
            whiteSpace: "nowrap",
            overflow: "hidden",
            textOverflow: "ellipsis",
          }}
        >
          {subtitle}
        </div>
      ) : null}
    </div>
    {trailing}
    {divider ? (
      <div
        style={{
          position: "absolute",
          left: icon ? 120 : 32,
          right: 0,
          bottom: 0,
          height: 1,
          background: ios.separator,
        }}
      />
    ) : null}
  </div>
);

export const Chevron: React.FC = () => (
  <svg width="20" height="34" viewBox="0 0 20 34" fill="none">
    <path
      d="M3 3l13 14L3 31"
      stroke={ios.textTertiary}
      strokeWidth={4}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const Checkmark: React.FC<{ color?: string }> = ({
  color = ios.blue,
}) => (
  <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
    <path
      d="M6 21l9 9 19-21"
      stroke={color}
      strokeWidth={5}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const Toggle: React.FC<{ on: boolean }> = ({ on }) => (
  <div
    style={{
      width: 92,
      height: 56,
      borderRadius: 28,
      background: on ? ios.green : "#39393D",
      position: "relative",
      transition: "none",
    }}
  >
    <div
      style={{
        position: "absolute",
        top: 4,
        left: on ? 40 : 4,
        width: 48,
        height: 48,
        borderRadius: "50%",
        background: "#fff",
      }}
    />
  </div>
);

// Pill button (e.g. blue "Next" / "New Automation")
export const PillButton: React.FC<{
  label: string;
  bg?: string;
  color?: string;
  style?: React.CSSProperties;
}> = ({ label, bg = ios.blue, color = "#fff", style }) => (
  <div
    style={{
      background: bg,
      color,
      fontWeight: 600,
      fontSize: 36,
      padding: "20px 44px",
      borderRadius: 40,
      ...style,
    }}
  >
    {label}
  </div>
);
