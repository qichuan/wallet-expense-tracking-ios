import "./index.css";
import { Composition } from "remotion";
import {
  AnnotatedSetup,
  TOTAL_FRAMES,
  COMP_W,
  COMP_H,
} from "./annotated/AnnotatedSetup";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="SetupAutomation"
        component={AnnotatedSetup}
        durationInFrames={TOTAL_FRAMES}
        fps={30}
        width={COMP_W}
        height={COMP_H}
      />
    </>
  );
};
