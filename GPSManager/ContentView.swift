import SwiftUI
import CoreLocation
import MapKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var speed: Double = 0
    @Published var signalStrength: Int = 0
    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var course: Double?
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
        self.locationManager.startUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        speed = location.speed >= 0 ? location.speed : 0
        signalStrength = Int(location.horizontalAccuracy)
        self.location = location
        self.course = location.course >= 0 ? location.course : nil
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.heading = newHeading
    }
}

enum SpeedUnit: String, CaseIterable {
    case mps = "m/s"
    case kmh = "km/h"
    case mph = "mph"
    
    func convert(_ speed: Double) -> Double {
        switch self {
        case .mps: return speed
        case .kmh: return speed * 3.6
        case .mph: return speed * 2.23694
        }
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var selectedUnit: SpeedUnit = .mps
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SpeedView(locationManager: locationManager, selectedUnit: $selectedUnit)
                .tabItem {
                    Image(systemName: "speedometer")
                    Text("Speed")
                }
                .tag(0)
            
            MapView(locationManager: locationManager, selectedUnit: selectedUnit)
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
                .tag(1)
        }
    }
}

struct SpeedView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var selectedUnit: SpeedUnit
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    signalStrengthView
                }
                .padding()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 250, height: 250)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(selectedUnit.convert(self.locationManager.speed) / selectedUnit.convert(50), 1)))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .frame(width: 250, height: 250)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: locationManager.speed)
                    
                    Divider()
                    
                    VStack {
                        Text(String(format: "%.1f", selectedUnit.convert(self.locationManager.speed)))
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                        Text(selectedUnit.rawValue)
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                    }
                }
                
                Picker("Speed Unit", selection: $selectedUnit) {
                    ForEach(SpeedUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                Spacer()
            }
        }
    }
    
    private var signalStrengthView: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<5) { index in
                Rectangle()
                    .fill(index < self.signalStrengthLevel ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(index + 1) * 4)
            }
        }
    }
    
    private var signalStrengthLevel: Int {
        switch locationManager.signalStrength {
        case 0...5: return 4
        case 6...10: return 3
        case 11...20: return 2
        case 21...40: return 1
        default: return 0
        }
    }
}

struct MapView: View {
    @ObservedObject var locationManager: LocationManager
    let selectedUnit: SpeedUnit
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ))
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $position) {
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .edgesIgnoringSafeArea(.all)
            .onReceive(locationManager.$location) { location in
                if let location = location {
                    position = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
            
            LocationInfoView(locationManager: locationManager, selectedUnit: selectedUnit)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .padding()
        }
    }
}

struct LocationInfoView: View {
    @ObservedObject var locationManager: LocationManager
    let selectedUnit: SpeedUnit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Speed: \(String(format: "%.1f", selectedUnit.convert(locationManager.speed))) \(selectedUnit.rawValue)")
            if let location = locationManager.location {
                Text("Altitude: \(String(format: "%.1f", location.altitude)) m")
                Text("Latitude: \(String(format: "%.6f", location.coordinate.latitude))°")
                Text("Longitude: \(String(format: "%.6f", location.coordinate.longitude))°")
            }
            if let heading = locationManager.heading {
                Text("Heading: \(String(format: "%.1f", heading.trueHeading))°")
            }
            if let course = locationManager.course {
                Text("Course: \(String(format: "%.1f", course))°")
            }
        }
        .font(.system(size: 14))
        .foregroundColor(.white)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

