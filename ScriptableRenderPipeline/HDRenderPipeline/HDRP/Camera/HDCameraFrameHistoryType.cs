using UnityEngine.Serialization;

namespace UnityEngine.Experimental.Rendering.HDPipeline
{
    public enum HDCameraFrameHistoryType
    {
        DepthPyramid,
        ColorPyramid,
        MotionVectors,
        VolumetricLighting,
        Count
    }
}
