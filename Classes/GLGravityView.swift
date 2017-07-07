//
//  GLGravityView.swift
//  GLGravity
//
//  Translated by OOPer in cooperation with shlab.jp, on 2014/12/28.
//
//
/*
     File: GLGravityView.h
     File: GLGravityView.m
 Abstract: This class wraps the CAEAGLLayer from CoreAnimation into a convenient
 UIView subclass. The view content is basically an EAGL surface you render your
 OpenGL scene into.  Note that setting the view non-opaque will only work if the
 EAGL surface has an alpha channel.
  Version: 2.2

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2010 Apple Inc. All Rights Reserved.

*/

import UIKit
import OpenGLES

private func squaredSum<T: BinaryFloatingPoint>(_ x: T, _ y: T, _ z: T) -> T {return x*x + y*y + z*z}

@objc(GLGravityView)
class GLGravityView: UIView {
    // The pixel dimensions of the backbuffer
    private var backingWidth: GLint = 0
    private var backingHeight: GLint = 0
    
    private var context: EAGLContext!
    
    // OpenGL names for the renderbuffer and framebuffers used to render to this view
    private var viewRenderbuffer: GLuint = 0, viewFramebuffer: GLuint = 0
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    private var depthRenderbuffer: GLuint = 0
    
    private var animating: Bool = false
    private var displayLinkSupported: Bool = false
    private var _animationFrameInterval: Int = 0
    // Use of the CADisplayLink class is the preferred method for controlling your animation timing.
    // CADisplayLink will link to the main display and fire every vsync when added to a given run-loop.
    // The NSTimer class is used only as fallback when running on a pre 3.1 device where CADisplayLink
    // isn't available.
    private var displayLink: CADisplayLink!
    private var animationTimer: Timer!
    
    var accel: [Double] = [0, 0, 0]
    
    
    // CONSTANTS
    private let kTeapotScale: GLfloat = 3.0
    
    // MACROS
    private func DEGREES_TO_RADIANS(_ angle: GLfloat) -> GLfloat {return (angle / 180.0 * .pi)}
    
    
    // Implement this to override the default layer class (which is [CALayer class]).
    // We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
    override class var layerClass : AnyClass {
        return CAEAGLLayer.self
    }
    
    // The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
    required init?(coder: NSCoder) {
        
        super.init(coder: coder)
        let eaglLayer = self.layer as! CAEAGLLayer
        
        eaglLayer.isOpaque = true
        eaglLayer.drawableProperties = [kEAGLDrawablePropertyRetainedBacking: false,
            kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8]
        
        context = EAGLContext(api: .openGLES1)
        
        if context == nil || !EAGLContext.setCurrent(context) {
            fatalError("EAGLContext.setCurrentContext(context) failed")
        }
        
        animating = false
        displayLinkSupported = false
        animationFrameInterval = 1
        displayLink = nil
        animationTimer = nil
        
        // A system version of 3.1 or greater is required to use CADisplayLink. The NSTimer
        // class is used as fallback when it isn't available.
        displayLinkSupported = (objc_getClass("CADisplayLink") != nil)
        
        self.setupView()
    }
    
    private func setupView() {
        let lightAmbient: [GLfloat] = [0.2, 0.2, 0.2, 1.0]
        let lightDiffuse: [GLfloat] = [1.0, 0.6, 0.0, 1.0]
        let matAmbient: [GLfloat] = [0.6, 0.6, 0.6, 1.0]
        let matDiffuse: [GLfloat] = [1.0, 1.0, 1.0, 1.0]
        let matSpecular: [GLfloat] = [1.0, 1.0, 1.0, 1.0]
        let lightPosition: [GLfloat] = [0.0, 0.0, 1.0, 0.0]
        let lightShininess: GLfloat = 100.0
        let zNear: GLfloat = 0.1
        let zFar: GLfloat = 1000.0
        let fieldOfView: GLfloat = 60.0
        var size: GLfloat = 0
        
        //Configure OpenGL lighting
        glEnable(GLenum(GL_LIGHTING))
        glEnable(GLenum(GL_LIGHT0))
        glMaterialfv(GLenum(GL_FRONT_AND_BACK), GLenum(GL_AMBIENT), matAmbient)
        glMaterialfv(GLenum(GL_FRONT_AND_BACK), GLenum(GL_DIFFUSE), matDiffuse)
        glMaterialfv(GLenum(GL_FRONT_AND_BACK), GLenum(GL_SPECULAR), matSpecular)
        glMaterialf(GLenum(GL_FRONT_AND_BACK), GLenum(GL_SHININESS), lightShininess)
        glLightfv(GLenum(GL_LIGHT0), GLenum(GL_AMBIENT), lightAmbient)
        glLightfv(GLenum(GL_LIGHT0), GLenum(GL_DIFFUSE), lightDiffuse)
        glLightfv(GLenum(GL_LIGHT0), GLenum(GL_POSITION), lightPosition)
        glShadeModel(GLenum(GL_SMOOTH))
        glEnable(GLenum(GL_DEPTH_TEST))
        
        //Configure OpenGL arrays
        glEnableClientState(GLenum(GL_VERTEX_ARRAY))
        glEnableClientState(GLenum(GL_NORMAL_ARRAY))
        glVertexPointer(3 ,GLenum(GL_FLOAT), 0, teapot_vertices)
        glNormalPointer(GLenum(GL_FLOAT), 0, teapot_normals)
        glEnable(GLenum(GL_NORMALIZE))
        
        //Set the OpenGL projection matrix
        glMatrixMode(GLenum(GL_PROJECTION))
        size = zNear * tanf(DEGREES_TO_RADIANS(fieldOfView) / 2.0)
        let rect = self.bounds
        glFrustumf(-size, size, -size / GLfloat(rect.size.width / rect.size.height), size / GLfloat(rect.size.width / rect.size.height), zNear, zFar)
        glViewport(0, 0, GLint(rect.size.width), GLint(rect.size.height))
        
        //Make the OpenGL modelview matrix the default
        glMatrixMode(GLenum(GL_MODELVIEW))
    }
    
    // Updates the OpenGL view
    func drawView() {
        // Make sure that you are drawing to the current context
        EAGLContext.setCurrent(context)
        
        glBindFramebufferOES(GLenum(GL_FRAMEBUFFER_OES), viewFramebuffer)
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        
        var length: GLfloat = 0
        
        //Make sure we have a big enough acceleration vector
        length = sqrtf(GLfloat(squaredSum(accel[0], accel[1], accel[2])))
        
        //Setup model view matrix
        glLoadIdentity()
        glTranslatef(0.0, -0.1, -1.0)
        glScalef(kTeapotScale, kTeapotScale, kTeapotScale)
        
        if length >= 0.1 {
            //Clear matrix to be used to rotate from the current referential to one based on the gravity vector
            var matrix: [GLfloat] = [
                0, 0, 0, 0,
                0, 0, 0, 0,
                0, 0, 0, 0,
                0, 0, 0, 0,
            ]
            matrix[3*4+3] = 1.0
            
            //Setup first matrix column as gravity vector
            matrix[0*4+0] = GLfloat(accel[0]) / length
            matrix[0*4+1] = GLfloat(accel[1]) / length
            matrix[0*4+2] = GLfloat(accel[2]) / length
            
            //Setup second matrix column as an arbitrary vector in the plane perpendicular to the gravity vector {Gx, Gy, Gz} defined by by the equation "Gx * x + Gy * y + Gz * z = 0" in which we arbitrarily set x=0 and y=1
            matrix[1*4+0] = 0.0
            matrix[1*4+1] = 1.0
            matrix[1*4+2] = -GLfloat(accel[1] / accel[2])
            //###Expression is too complex...
            //length = sqrtf(matrix[1][0] * matrix[1][0] + matrix[1][1] * matrix[1][1] + matrix[1][2] * matrix[1][2])
            length = sqrtf(squaredSum(matrix[1*4+0], matrix[1*4+1], matrix[1*4+2]))
            matrix[1*4+0] /= length
            matrix[1*4+1] /= length
            matrix[1*4+2] /= length
            
            //Setup third matrix column as the cross product of the first two
            matrix[2*4+0] = matrix[0*4+1] * matrix[1*4+2] - matrix[0*4+2] * matrix[1*4+1]
            matrix[2*4+1] = matrix[1*4+0] * matrix[0*4+2] - matrix[1*4+2] * matrix[0*4+0]
            matrix[2*4+2] = matrix[0*4+0] * matrix[1*4+1] - matrix[0*4+1] * matrix[1*4+0]
            
            //Finally load matrix
            glMultMatrixf(matrix)
            
            // Rotate a bit more so that its where we want it.
            glRotatef(90.0, 0.0, 0.0, 1.0)
        } else {
            // If we're in the simulator we'd like to do something more interesting than just sit there
            // But if we're on a device, we want to just let the accelerometer do the work for us without a fallback.
            #if arch(x86_64) || arch(i386)  //iOS Simulator
                struct My {
                static var spinX: GLfloat = 0.0, spinY: GLfloat = 0.0
                }
                glRotatef(My.spinX, 0.0, 0.0, 1.0)
                glRotatef(My.spinY, 0.0, 1.0, 0.0)
                glRotatef(90.0, 1.0, 0.0, 0.0)
                My.spinX += 1.0
                My.spinY += 0.25
            #endif
        }
        
        // Draw teapot. The new_teapot_indicies array is an RLE (run-length encoded) version of the teapot_indices array in teapot.h
        for teapot_indices in new_teapot_indicies {
            let mode: GLenum = GLenum(GL_TRIANGLE_STRIP)
            let size: GLsizei = GLsizei(teapot_indices.count)
            let type: GLenum = GLenum(GL_UNSIGNED_SHORT)
            glDrawElements(mode, size, type, teapot_indices)
        }
        
        glBindRenderbufferOES(GLenum(GL_RENDERBUFFER_OES), viewRenderbuffer)
        context.presentRenderbuffer(Int(GL_RENDERBUFFER_OES))
    }
    
    // If our view is resized, we'll be asked to layout subviews.
    // This is the perfect opportunity to also update the framebuffer so that it is
    // the same size as our display area.
    override func layoutSubviews() {
        EAGLContext.setCurrent(context)
        self.destroyFramebuffer()
        self.createFramebuffer()
        self.drawView()
    }
    
    @discardableResult
    private func createFramebuffer() -> Bool {
        // Generate IDs for a framebuffer object and a color renderbuffer
        glGenFramebuffersOES(1, &viewFramebuffer)
        glGenRenderbuffersOES(1, &viewRenderbuffer)
        
        glBindFramebufferOES(GLenum(GL_FRAMEBUFFER_OES), viewFramebuffer)
        glBindRenderbufferOES(GLenum(GL_RENDERBUFFER_OES), viewRenderbuffer)
        // This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
        // allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
        context.renderbufferStorage(Int(GL_RENDERBUFFER_OES), from: self.layer as! EAGLDrawable)
        glFramebufferRenderbufferOES(GLenum(GL_FRAMEBUFFER_OES), GLenum(GL_COLOR_ATTACHMENT0_OES), GLenum(GL_RENDERBUFFER_OES), viewRenderbuffer)
        
        glGetRenderbufferParameterivOES(GLenum(GL_RENDERBUFFER_OES), GLenum(GL_RENDERBUFFER_WIDTH_OES), &backingWidth)
        glGetRenderbufferParameterivOES(GLenum(GL_RENDERBUFFER_OES), GLenum(GL_RENDERBUFFER_HEIGHT_OES), &backingHeight)
        
        // For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
        glGenRenderbuffersOES(1, &depthRenderbuffer)
        glBindRenderbufferOES(GLenum(GL_RENDERBUFFER_OES), depthRenderbuffer)
        glRenderbufferStorageOES(GLenum(GL_RENDERBUFFER_OES), GLenum(GL_DEPTH_COMPONENT16_OES), backingWidth, backingHeight)
        glFramebufferRenderbufferOES(GLenum(GL_FRAMEBUFFER_OES), GLenum(GL_DEPTH_ATTACHMENT_OES), GLenum(GL_RENDERBUFFER_OES), depthRenderbuffer)
        
        if glCheckFramebufferStatusOES(GLenum(GL_FRAMEBUFFER_OES)) != GLenum(GL_FRAMEBUFFER_COMPLETE_OES) {
            NSLog("failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GLenum(GL_FRAMEBUFFER_OES)))
            return false
        }
        
        return true
    }
    
    // Clean up any buffers we have allocated.
    private func destroyFramebuffer() {
        glDeleteFramebuffersOES(1, &viewFramebuffer)
        viewFramebuffer = 0
        glDeleteRenderbuffersOES(1, &viewRenderbuffer)
        viewRenderbuffer = 0
        
        if depthRenderbuffer != 0 {
            glDeleteRenderbuffersOES(1, &depthRenderbuffer)
            depthRenderbuffer = 0
        }
    }
    
    private dynamic var animationFrameInterval: Int {
        get {
            return _animationFrameInterval
        }
        
        set {
            // Frame interval defines how many display frames must pass between each time the
            // display link fires. The display link will only fire 30 times a second when the
            // frame internal is two on a display that refreshes 60 times a second. The default
            // frame interval setting of one will fire 60 times a second when the display refreshes
            // at 60 times a second. A frame interval setting of less than one results in undefined
            // behavior.
            if newValue >= 1 {
                _animationFrameInterval = newValue
                
                if animating {
                    self.stopAnimation()
                    self.startAnimation()
                }
            }
        }
    }
    
    func startAnimation() {
        if !animating {
            if displayLinkSupported {
                // CADisplayLink is API new to iPhone SDK 3.1. Compiling against earlier versions will result in a warning, but can be dismissed
                // if the system version runtime check for CADisplayLink exists in -initWithCoder:. The runtime check ensures this code will
                // not be called in system versions earlier than 3.1.
                
                displayLink = CADisplayLink(target: self, selector: #selector(GLGravityView.drawView))
                displayLink.frameInterval = animationFrameInterval
                displayLink.add(to: .current, forMode: .defaultRunLoopMode)
            } else {
                animationTimer = Timer.scheduledTimer(timeInterval: TimeInterval((1.0 / 60.0) * TimeInterval(animationFrameInterval)), target: self, selector: #selector(GLGravityView.drawView), userInfo: nil, repeats: true)
            }
            
            animating = true
        }
    }
    
    func stopAnimation() {
        if animating {
            if displayLinkSupported {
                displayLink.invalidate()
                displayLink = nil
            } else {
                animationTimer.invalidate()
                animationTimer = nil
            }
            
            animating = false
        }
    }
    
    deinit {
        
        if EAGLContext.current() === context {
            EAGLContext.setCurrent(nil)
        }
        
    }
    
}
