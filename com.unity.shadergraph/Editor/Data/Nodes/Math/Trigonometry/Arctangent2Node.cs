using UnityEngine.ShaderGraph.Hlsl;
using static UnityEngine.ShaderGraph.Hlsl.Intrinsics;

namespace UnityEditor.ShaderGraph
{
    [Title("Math", "Trigonometry", "Arctangent2")]
    class Arctangent2Node : CodeFunctionNode
    {
        public Arctangent2Node()
        {
            name = "Arctangent2";
        }

        [HlslCodeGen]
        static void Unity_Arctangent2(
            [Slot(0, Binding.None)] [AnyDimension] Float4 A,
            [Slot(1, Binding.None)] [AnyDimension] Float4 B,
            [Slot(2, Binding.None)] [AnyDimension] out Float4 Out)
        {
            Out = atan2(A, B);
        }
    }
}
