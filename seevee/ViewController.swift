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

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let result = sceneView.hitTest(touch.location(in: sceneView), types: [ARHitTestResult.ResultType.featurePoint])
        guard let hitResult = result.last else { return }
        let hitTransform = SCNMatrix4(hitResult.worldTransform)
        let hitVector = SCNVector3Make(hitTransform.m41, hitTransform.m42, hitTransform.m43)
        createBall(position: hitVector)
    }
    
    func createBall(position: SCNVector3) {
        let plane = SCNPlane(width: 0.1, height: 0.1)
        plane.firstMaterial?.diffuse.contents = UIColor.black
        let planeNode = SCNNode(geometry: plane)
        
        let text = SCNText(string: "Hello!", extrusionDepth: 1)
        text.firstMaterial?.diffuse.contents = UIColor.white
        let textNode = SCNNode(geometry: text)
        textNode.position = SCNVector3(x: 0, y: 0, z: 0)
        textNode.scale = SCNVector3(x: 0.001, y: 0.001, z: 0.001)
        planeNode.addChildNode(textNode)
        
        
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        planeNode.constraints = [billboardConstraint]
        planeNode.position = position
        
        sceneView.scene.rootNode.addChildNode(planeNode)
        sceneView.autoenablesDefaultLighting = true
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
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
