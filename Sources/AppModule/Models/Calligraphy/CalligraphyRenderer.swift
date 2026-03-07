import MetalKit
import UIKit

/// Metalレンダリング用の頂点データ（シェーダーのBrushVertexInと対応）
struct BrushVertex {
    var position: SIMD2<Float>  // 画面座標
    var crossU: Float           // 横断方向UV (0=左端, 1=右端)
    var alongV: Float           // 進行方向UV
    var speed: Float            // そのポイントでの移動速度
    var pressure: Float         // 筆圧
}

/// Metalレンダリング用のユニフォーム（シェーダーのBrushUniformsと対応）
struct BrushUniforms {
    var viewportSize: SIMD2<Float>
    var inkColor: SIMD4<Float>
}

/// 毛筆ストロークをMetalでレンダリングするレンダラー
final class CalligraphyRenderer: NSObject, MTKViewDelegate, @unchecked Sendable {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    /// レンダリング対象のストローク
    var strokes: [CalligraphyStroke] = []
    /// 墨色
    var inkColor: UIColor = .black
    /// 基本線幅
    var baseLineWidth: CGFloat = 20
    /// 背景色
    var backgroundColor: UIColor = .clear

    /// ビューポートサイズ（ピクセル単位）
    private var viewportSize: CGSize = .zero

    @MainActor init?(mtkView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = queue

        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.isOpaque = false
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true

        // 頂点ディスクリプタ
        let vertexDescriptor = MTLVertexDescriptor()
        // position: float2
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        // crossU: float
        vertexDescriptor.attributes[1].format = .float
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        // alongV: float
        vertexDescriptor.attributes[2].format = .float
        vertexDescriptor.attributes[2].offset = MemoryLayout<SIMD2<Float>>.stride + MemoryLayout<Float>.stride
        vertexDescriptor.attributes[2].bufferIndex = 0
        // speed: float
        vertexDescriptor.attributes[3].format = .float
        vertexDescriptor.attributes[3].offset = MemoryLayout<SIMD2<Float>>.stride + MemoryLayout<Float>.stride * 2
        vertexDescriptor.attributes[3].bufferIndex = 0
        // pressure: float
        vertexDescriptor.attributes[4].format = .float
        vertexDescriptor.attributes[4].offset = MemoryLayout<SIMD2<Float>>.stride + MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes[4].bufferIndex = 0
        // stride
        vertexDescriptor.layouts[0].stride = MemoryLayout<BrushVertex>.stride
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        // シェーダーライブラリ（Swift 文字列から動的コンパイル）
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: EmbeddedMetalShaders.calligraphyBrush, options: nil)
        } catch {
            print("Failed to compile calligraphy Metal shader source: \(error)")
            return nil
        }
        guard let vertexFunc = library.makeFunction(name: "calligraphyVertex"),
              let fragmentFunc = library.makeFunction(name: "calligraphyFragment") else {
            print("Failed to resolve calligraphy shader functions")
            return nil
        }

        // パイプライン
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        // アルファブレンディング
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline: \(error)")
            return nil
        }

        super.init()
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

        // 背景色の設定
        let bgComponents = backgroundColor.cgColor.components ?? [0, 0, 0, 0]
        let bgCount = backgroundColor.cgColor.numberOfComponents
        if bgCount >= 4 {
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: Double(bgComponents[0]),
                green: Double(bgComponents[1]),
                blue: Double(bgComponents[2]),
                alpha: Double(bgComponents[3])
            )
        } else if bgCount >= 2 {
            // グレースケール
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: Double(bgComponents[0]),
                green: Double(bgComponents[0]),
                blue: Double(bgComponents[0]),
                alpha: Double(bgComponents[1])
            )
        }
        renderPassDescriptor.colorAttachments[0].loadAction = .clear

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        encoder.setRenderPipelineState(pipelineState)

        let scale = view.contentScaleFactor
        let vpSize = SIMD2<Float>(Float(view.bounds.width * scale), Float(view.bounds.height * scale))

        // 墨色
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        inkColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        var uniforms = BrushUniforms(
            viewportSize: vpSize,
            inkColor: SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
        )
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<BrushUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<BrushUniforms>.stride, index: 1)

        // 各ストロークを描画
        for stroke in strokes where !stroke.isEraser {
            let vertices = buildTriangleStrip(for: stroke, scale: scale)
            guard vertices.count >= 3 else { continue }

            let buffer = device.makeBuffer(
                bytes: vertices,
                length: vertices.count * MemoryLayout<BrushVertex>.stride,
                options: .storageModeShared
            )
            if let buffer = buffer {
                encoder.setVertexBuffer(buffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
            }
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - ストローク→メッシュ変換

    /// ストロークをtriangle stripメッシュに変換
    private func buildTriangleStrip(for stroke: CalligraphyStroke, scale: CGFloat) -> [BrushVertex] {
        let rawPoints = stroke.points
        guard rawPoints.count >= 2 else { return [] }

        // Catmull-Romスプラインで補間したポイント列を生成
        let interpolated = catmullRomInterpolate(points: rawPoints)
        guard interpolated.count >= 2 else { return [] }

        // 各ポイントの速度を計算
        var speeds: [Float] = []
        for i in 0..<interpolated.count {
            if i == 0 {
                speeds.append(0)
            } else {
                let dx = interpolated[i].position.x - interpolated[i-1].position.x
                let dy = interpolated[i].position.y - interpolated[i-1].position.y
                let dt = max(interpolated[i].timestamp - interpolated[i-1].timestamp, 0.001)
                let spd = sqrt(dx*dx + dy*dy) / dt
                speeds.append(Float(spd))
            }
        }

        // 総距離を計算（alongV用）
        var cumDistances: [Float] = [0]
        for i in 1..<interpolated.count {
            let dx = Float(interpolated[i].position.x - interpolated[i-1].position.x)
            let dy = Float(interpolated[i].position.y - interpolated[i-1].position.y)
            cumDistances.append(cumDistances[i-1] + sqrt(dx*dx + dy*dy))
        }
        let totalDist = max(cumDistances.last ?? 1, 1)

        var vertices: [BrushVertex] = []

        for i in 0..<interpolated.count {
            let point = interpolated[i]
            let pos = SIMD2<Float>(Float(point.position.x * scale), Float(point.position.y * scale))

            // 法線方向を計算
            let normal: SIMD2<Float>
            if i == 0 {
                let next = SIMD2<Float>(Float(interpolated[1].position.x * scale), Float(interpolated[1].position.y * scale))
                let dir = next - pos
                normal = normalize(SIMD2<Float>(-dir.y, dir.x))
            } else if i == interpolated.count - 1 {
                let prev = SIMD2<Float>(Float(interpolated[i-1].position.x * scale), Float(interpolated[i-1].position.y * scale))
                let dir = pos - prev
                normal = normalize(SIMD2<Float>(-dir.y, dir.x))
            } else {
                let prev = SIMD2<Float>(Float(interpolated[i-1].position.x * scale), Float(interpolated[i-1].position.y * scale))
                let next = SIMD2<Float>(Float(interpolated[i+1].position.x * scale), Float(interpolated[i+1].position.y * scale))
                let dir = next - prev
                let len = length(dir)
                if len > 0.001 {
                    normal = normalize(SIMD2<Float>(-dir.y, dir.x))
                } else {
                    normal = SIMD2<Float>(0, 1)
                }
            }

            // 幅の計算: 筆圧で太く、速度で細く
            let pressure = Float(point.pressure)
            let speedFactor = max(1.0 - speeds[i] / 1600.0, 0.55)
            let pressureFactor = 0.65 + pressure * 0.6
            let halfWidth = Float(baseLineWidth * scale) * 0.95 * pressureFactor * speedFactor

            // テーパー（入り・抜き）
            let t = cumDistances[i] / totalDist
            let taperIn = min(t / 0.12, 1.0)
            let taperOut = min((1.0 - t) / 0.12, 1.0)
            let taper = taperIn * taperOut
            let finalHalfWidth = halfWidth * taper

            let alongV = t
            let spd = speeds[i]
            let prs = pressure

            // 左右の頂点ペア
            let leftPos = pos - normal * finalHalfWidth
            let rightPos = pos + normal * finalHalfWidth

            vertices.append(BrushVertex(position: leftPos, crossU: 0.0, alongV: alongV, speed: spd, pressure: prs))
            vertices.append(BrushVertex(position: rightPos, crossU: 1.0, alongV: alongV, speed: spd, pressure: prs))
        }

        return vertices
    }

    /// Catmull-Romスプラインでポイントを補間
    private func catmullRomInterpolate(points: [CalligraphyPoint]) -> [CalligraphyPoint] {
        guard points.count >= 2 else { return points }

        var result: [CalligraphyPoint] = []
        // セグメント数に応じた補間
        let segmentsPerPair = 6

        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]

            for j in 0..<segmentsPerPair {
                let t = CGFloat(j) / CGFloat(segmentsPerPair)
                let tt = t * t
                let ttt = tt * t

                // Catmull-Romの係数
                let q0 = -ttt + 2*tt - t
                let q1 = 3*ttt - 5*tt + 2
                let q2 = -3*ttt + 4*tt + t
                let q3 = ttt - tt

                let x = 0.5 * (p0.position.x * q0 + p1.position.x * q1 + p2.position.x * q2 + p3.position.x * q3)
                let y = 0.5 * (p0.position.y * q0 + p1.position.y * q1 + p2.position.y * q2 + p3.position.y * q3)
                let pressure = p1.pressure + (p2.pressure - p1.pressure) * t
                let timestamp = p1.timestamp + (p2.timestamp - p1.timestamp) * t

                result.append(CalligraphyPoint(
                    position: CGPoint(x: x, y: y),
                    pressure: pressure,
                    timestamp: timestamp
                ))
            }
        }

        // 最後のポイントを追加
        if let last = points.last {
            result.append(last)
        }

        return result
    }

    // MARK: - 画像キャプチャ

    /// キャンバスの描画内容をUIImageとして取得
    func captureImage(viewSize: CGSize, scale: CGFloat) -> UIImage? {
        guard !strokes.isEmpty else { return nil }

        // 描画があるか確認
        let drawingStrokes = strokes.filter { !$0.isEraser }
        guard !drawingStrokes.isEmpty else { return nil }

        let pixelWidth = Int(viewSize.width * scale)
        let pixelHeight = Int(viewSize.height * scale)

        // オフスクリーンテクスチャ
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: pixelWidth,
            height: pixelHeight,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return nil }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear

        // 背景色の設定
        let bgComponents = backgroundColor.cgColor.components ?? [0, 0, 0, 0]
        let bgCount = backgroundColor.cgColor.numberOfComponents
        if bgCount >= 4 {
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: Double(bgComponents[0]),
                green: Double(bgComponents[1]),
                blue: Double(bgComponents[2]),
                alpha: Double(bgComponents[3])
            )
        } else if bgCount >= 2 {
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: Double(bgComponents[0]),
                green: Double(bgComponents[0]),
                blue: Double(bgComponents[0]),
                alpha: Double(bgComponents[1])
            )
        } else {
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        encoder.setRenderPipelineState(pipelineState)

        let vpSize = SIMD2<Float>(Float(pixelWidth), Float(pixelHeight))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        inkColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        var uniforms = BrushUniforms(
            viewportSize: vpSize,
            inkColor: SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
        )
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<BrushUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<BrushUniforms>.stride, index: 1)

        for stroke in drawingStrokes {
            let vertices = buildTriangleStrip(for: stroke, scale: scale)
            guard vertices.count >= 3 else { continue }

            let buffer = device.makeBuffer(
                bytes: vertices,
                length: vertices.count * MemoryLayout<BrushVertex>.stride,
                options: .storageModeShared
            )
            if let buffer = buffer {
                encoder.setVertexBuffer(buffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
            }
        }

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // テクスチャからUIImageに変換
        let bytesPerRow = pixelWidth * 4
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * pixelHeight)
        texture.getBytes(&pixelData, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, pixelWidth, pixelHeight), mipmapLevel: 0)

        // BGRAからRGBAに変換
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let b = pixelData[i]
            let r = pixelData[i + 2]
            pixelData[i] = r
            pixelData[i + 2] = b
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixelData,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let cgImage = context.makeImage() else { return nil }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}
