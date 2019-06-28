using UnityEngine.ShaderGraph.Hlsl;
using static UnityEngine.ShaderGraph.Hlsl.Intrinsics;

namespace UnityEditor.ShaderGraph
{
    [Title("Math", "Derivative", "DDX")]
    class DDXNode : CodeFunctionNode
    {
        public DDXNode()
        {
            name = "DDX";
        }

        [HlslCodeGen]
        static void Unity_DDX(
            [Slot(0, Binding.None)] [AnyDimension] Float4 In,
            [Slot(1, Binding.None)] [AnyDimension] out Float4 Out)
        {
            Out = ddx(In);
        }
    }
}
