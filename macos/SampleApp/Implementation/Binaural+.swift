//
//  Copyright (c) 2019 - 2027 Comdigis, Argentina
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import IO
import Foundation

struct Control: Identifiable, Equatable {
    let id: ID
    let label: String
    let variant: ControlVariant
    var value: Float
    
    enum ControlVariant: Equatable {
        case continuous(range: ClosedRange<Float>)
        case discrete(range: ClosedRange<Float>, step: Float)
        
        internal var range: ClosedRange<Float> {
            switch self {
            case .discrete(let range, _): return range
            case .continuous(let range):  return range
            }
        }
        internal var stepValue: Float? {
            switch self {
            case .discrete(_, let step): return step
            case .continuous:            return nil
            }
        }
    }
}

struct BinauralComponent {
    
    var name: String
    var parameters: [Control] = []
    var settings: [Control] = []
    
    internal init(description: String) {
        let precondition: Bool = description.count > 0
        assertion(precondition, message: "Unexpected precondition failure: Condition mismatch")
        
        self.name = description
        self.parameters = buildParameters()
        self.settings = buildSettings()
    }
    
    func buildSettings() -> [Control] {
        let precondition: Bool = settings.count == 0
        assertion(precondition, message: "Unexpected precondition failure: Condition mismatch")

        let items: [Control] = [
            .init(id: .innerRadius, label: "Inner Radius", variant: .continuous(range: 0.01...50.0), value: 5.0),
            .init(id: .outerRadius, label: "Outer Radius", variant: .continuous(range: 5.0...200.0), value: 15.0),
            .init(id: .rollOff, label: "Roll-Off", variant: .continuous(range: 0.0...10.0), value: 4.5),
            .init(id: .innerAngle, label: "Inner Cone Angle", variant: .continuous(range: 0.0...360.0), value: 40.0),
            .init(id: .outerAngle, label: "Outer Cone Angle", variant: .continuous(range: 0.0...360.0), value: 120.0),
            .init(id: .outerAngleGain, label: "Outer Cone Gain", variant: .continuous(range: 0.0...1.0), value: 0.2),
            .init(id: .distanceModel, label: "Distance Model", variant: .discrete(range: 0...2, step: 1), value: 1)
        ]
        
        return items
    }
    
    func buildParameters() -> [Control] {
        let precondition: Bool = parameters.count == 0
        assertion(precondition, message: "Unexpected precondition failure: Condition mismatch")

        let items: [Control] = [
            .init(id: .velocityX, label: "Velocity X", variant: .continuous(range: -25...25), value: 0.0),
            .init(id: .velocityY, label: "Velocity Y", variant: .continuous(range: -25...25), value: 0.0),
            .init(id: .velocityZ, label: "Velocity Z", variant: .continuous(range: -25...25), value: 0.0),
            .init(id: .orientationX, label: "Orientation X", variant: .continuous(range: -25...25), value: 0.0),
            .init(id: .orientationY, label: "Orientation Y", variant: .continuous(range: -25...25), value: 0.0),
            .init(id: .orientationZ, label: "Orientation Z", variant: .continuous(range: -25...25), value: 0.0),
            .init(id: .positionX, label: "Position X", variant: .continuous(range: -75...75), value: 0.0),
            .init(id: .positionY, label: "Position Y", variant: .continuous(range: -75...75), value: 0.0),
            .init(id: .positionZ, label: "Position Z", variant: .continuous(range: -75...75), value: -15.0)
        ]
        
        return items
    }

    static let database: BinauralDatabase = {
        let database = BinauralDatabase(location: URL.HRTF())
        database.loadSynchronously()
        return database
    }()
    
    func buildInternalGraphNode() -> IO.AudioNode {
        return IO.Binaural(database: BinauralComponent.database)
    }
    
}
