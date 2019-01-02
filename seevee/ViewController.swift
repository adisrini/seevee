//
//  ViewController.swift
//  seevee
//
//  Created by Aditya Srinivasan on 12/26/18.
//  Copyright © 2018 Aditya Srinivasan. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    // State
    var detectedDataAnchor: ARAnchor?
    var processing = false
    
    // CONSTANTS
    let CONTENT_NAME = "TEXT_CONTENT"
    let PLANE_NAME = "CONTENT_BG"
    let FONT_SCALE: Float = 0.005
    let PLANE_SCALE: Float = 30
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Set the session's delegate
        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable horizontal plane detection
        configuration.planeDetection = .horizontal

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSessionDelegate
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Only run one Vision request at a time
        if self.processing {
            return
        }
        
        self.processing = true
        
        // Create a Barcode Detection Request
        let request = VNDetectBarcodesRequest { (request, error) in
            
            // Get the first result out of the results, if there are any
            if let results = request.results, let result = results.first as? VNBarcodeObservation {
                // Get the bounding box for the bar code and find the center
                var rect = result.boundingBox
                
                // Flip coordinates
                rect = rect.applying(CGAffineTransform(scaleX: 1, y: -1))
                rect = rect.applying(CGAffineTransform(translationX: 0, y: 1))
                
                // Get center
                let center = CGPoint(x: rect.midX, y: rect.midY)
                
                // Go back to the main thread
                DispatchQueue.main.async {
                    
                    // Perform a hit test on the ARFrame to find a surface
                    let hitTestResults = frame.hitTest(center, types: [.featurePoint] )
                    
                    // If we have a result, process it
                    if let hitTestResult = hitTestResults.first {
                        
                        // If we already have an anchor, update the position and content of the attached node
                        if let detectedDataAnchor = self.detectedDataAnchor,
                            let node = self.sceneView.node(for: detectedDataAnchor) {
                            
                            node.transform = SCNMatrix4(hitTestResult.worldTransform)
                            
                            // Replace text
                            node.replaceChildNode(
                                node.childNode(withName: self.CONTENT_NAME, recursively: true)!,
                                with: self.createTextNode(string: result.payloadStringValue!)
                            )
                            
                            // Replace plane
                            node.replaceChildNode(
                                node.childNode(withName: self.PLANE_NAME, recursively: true)!,
                                with: self.createPlaneNode(
                                    color: self.normalizeUIColor(red: 48, green: 64, blue: 77, alpha: 0.8)
                                )
                            )
                        } else {
                            // Create an anchor. The node will be created in delegate methods
                            self.detectedDataAnchor = ARAnchor(transform: hitTestResult.worldTransform)
                            self.sceneView.session.add(anchor: self.detectedDataAnchor!)
                        }
                    }
                    
                    // Set processing flag off
                    self.processing = false
                }
                
            } else {
                // Set processing flag off
                self.processing = false
            }
        }
        
        // Process the request in the background
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Set it to recognize QR code only
                request.symbologies = [.QR]
                
                // Create a request handler using the captured image from the ARFrame
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage,
                                                                options: [:])
                // Process the request
                try imageRequestHandler.perform([request])
            } catch {
                
            }
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // If this is our anchor, create a node
        if self.detectedDataAnchor?.identifier == anchor.identifier {
            let textNode = createTextNode(string: "Loading...")
            let planeNode = createPlaneNode(color: UIColor.orange)
            
            let wrapperNode = SCNNode()
            wrapperNode.addChildNode(planeNode)
            wrapperNode.addChildNode(textNode)
            
            // Set its position based off the anchor
            wrapperNode.transform = SCNMatrix4(anchor.transform)
            
            return wrapperNode
        }
        
        return nil
    }
    
    func createTextNode(string: String) -> SCNNode {
        let text = SCNText(string: string, extrusionDepth: 0.2)
        text.firstMaterial?.diffuse.contents = UIColor.white
        text.font = UIFont.systemFont(ofSize: 1)
        let textNode = SCNNode(geometry: text)
        textNode.movabilityHint = .movable
        textNode.name = self.CONTENT_NAME
        let (min, max) = (text.boundingBox.min, text.boundingBox.max)
        let dx = min.x + 0.5 * (max.x - min.x)
        let dy = min.y + 0.5 * (max.y - min.y)
        let dz = min.z + 0.5 * (max.z - min.z)
        textNode.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
        textNode.scale = SCNVector3(x: self.FONT_SCALE, y: self.FONT_SCALE, z: self.FONT_SCALE)
        addBillboardConstraint(textNode)
        
        return textNode
    }
    
    func createPlaneNode(color: UIColor) -> SCNNode {
        let (width, height) = (4 / self.PLANE_SCALE, 3 / self.PLANE_SCALE)
        let plane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
        plane.firstMaterial?.diffuse.contents = color
        plane.firstMaterial?.lightingModel = .physicallyBased
        let planeNode = SCNNode(geometry: plane)
        addBillboardConstraint(planeNode)
        planeNode.movabilityHint = .movable
        planeNode.name = self.PLANE_NAME
        
        return planeNode
    }
    
    func addBillboardConstraint(_ node: SCNNode) {
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.all
        node.constraints = [billboardConstraint]
    }
    
    func normalizeUIColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> UIColor {
        return UIColor.init(
            red: red / 255,
            green: green / 255,
            blue: blue / 255,
            alpha: alpha
        )
    }
    
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
