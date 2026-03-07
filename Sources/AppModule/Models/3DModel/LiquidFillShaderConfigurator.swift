import Foundation
import SceneKit
import Metal
import simd

/// Metalシェーダーを3Dモデルに適用するための設定クラス
final class LiquidFillShaderConfigurator {

    /// SCNProgramを作成してマテリアルに適用
    static func applyLiquidFillShader(
        to node: SCNNode,
        device: MTLDevice,
        uniforms: (
            fillProgress: Float,
            time: Float,
            waveAmplitude: Float,
            waveFrequency: Float,
            liquidColor: SIMD4<Float>
        )
    ) {
        // Metalライブラリをロード（Swift文字列から動的コンパイル）
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: EmbeddedMetalShaders.liquidFill, options: nil)
        } catch {
            print("❌ Failed to compile the Metal source: \(error)")
            return
        }
        print("✅ Metal library compiled")

        // シェーダー関数が存在するか確認
        if library.makeFunction(name: "liquidFillVertex") != nil {
            print("✅ liquidFillVertex function found")
        } else {
            print("❌ liquidFillVertex function NOT found")
        }

        if library.makeFunction(name: "liquidFillFragment") != nil {
            print("✅ liquidFillFragment function found")
        } else {
            print("❌ liquidFillFragment function NOT found")
        }

        // SCNProgramの作成
        let program = SCNProgram()
        program.library = library
        program.vertexFunctionName = "liquidFillVertex"
        program.fragmentFunctionName = "liquidFillFragment"
        print("✅ SCNProgram created with shader functions")

        // 再帰的にすべてのジオメトリに適用
        applyProgramToNode(node, program: program, uniforms: uniforms)
    }

    /// ノードとその子ノードに再帰的にプログラムを適用
    private static func applyProgramToNode(
        _ node: SCNNode,
        program: SCNProgram,
        uniforms: (
            fillProgress: Float,
            time: Float,
            waveAmplitude: Float,
            waveFrequency: Float,
            liquidColor: SIMD4<Float>
        )
    ) {
        if let geometry = node.geometry {
            print("🎨 Applying shader to node with \(geometry.materials.count) materials")
            for (index, material) in geometry.materials.enumerated() {
                material.program = program
                print("   Material[\(index)]: Program set")

                // Uniformバッファをセット
                material.setValue(NSNumber(value: uniforms.fillProgress), forKey: "fillProgress")
                material.setValue(NSNumber(value: uniforms.time), forKey: "time")
                material.setValue(NSNumber(value: uniforms.waveAmplitude), forKey: "waveAmplitude")
                material.setValue(NSNumber(value: uniforms.waveFrequency), forKey: "waveFrequency")

                // SIMD4をData経由で渡す
                var color = uniforms.liquidColor
                let colorData = Data(bytes: &color, count: MemoryLayout<SIMD4<Float>>.size)
                material.setValue(colorData, forKey: "liquidColor")
                print("   Material[\(index)]: Uniforms set")
            }
        }

        for child in node.childNodes {
            applyProgramToNode(child, program: program, uniforms: uniforms)
        }
    }

    /// Uniformパラメータを更新（フレームごとに呼び出す）
    static func updateUniforms(
        on node: SCNNode,
        uniforms: (
            fillProgress: Float,
            time: Float,
            waveAmplitude: Float,
            waveFrequency: Float,
            liquidColor: SIMD4<Float>
        )
    ) {
        updateUniformsRecursive(node, uniforms: uniforms)
    }

    /// 再帰的にUniformを更新
    private static func updateUniformsRecursive(
        _ node: SCNNode,
        uniforms: (
            fillProgress: Float,
            time: Float,
            waveAmplitude: Float,
            waveFrequency: Float,
            liquidColor: SIMD4<Float>
        )
    ) {
        if let geometry = node.geometry {
            for material in geometry.materials {
                material.setValue(NSNumber(value: uniforms.fillProgress), forKey: "fillProgress")
                material.setValue(NSNumber(value: uniforms.time), forKey: "time")
                // 色と波形パラメータは通常変更しないが、必要なら更新可能
            }
        }

        for child in node.childNodes {
            updateUniformsRecursive(child, uniforms: uniforms)
        }
    }
}
