//
//  ColorComponents.swift
//  Assignment Manager
//
//  Created by Morris Richman on 7/17/25.
//

import SwiftUI

public struct ColorComponents: Codable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double
    
    public init(red: Double, green: Double, blue: Double, opacity: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }
    
    public init(_ color: Color) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var o: CGFloat = 0
        
#if canImport(UIKit)
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &o) else {
            // You can handle the failure here as you want
            self.red = 0
            self.green = 0
            self.blue = 0
            self.opacity = 0
            return
        }
#elseif canImport(AppKit)
        if let converted = NSColor(color).usingColorSpace(.deviceRGB) {
            converted.getRed(&r, green: &g, blue: &b, alpha: &o)
        }
#endif
        
        self.red = r
        self.green = g
        self.blue = b
        self.opacity = o
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let red = try container.decode(Double.self, forKey: .red)
        let green = try container.decode(Double.self, forKey: .green)
        let blue = try container.decode(Double.self, forKey: .blue)
        let opacity = try container.decode(Double.self, forKey: .opacity)
        
        if red > 1 {
            self.red = red/255
        } else {
            self.red = red
        }
        
        if green > 1 {
            self.green = green/255
        } else {
            self.green = green
        }
        
        if blue > 1 {
            self.blue = blue/255
        } else {
            self.blue = blue
        }
        
        if opacity > 1 {
            self.opacity = opacity/100
        } else {
            self.opacity = opacity
        }
    }
    
    public func toColor() -> Color {
        Color(
            red: red,
            green: green,
            blue: blue,
            opacity: opacity
        )
    }
}

extension Color {
    public func components() -> ColorComponents {
        return ColorComponents(self)
    }
}
