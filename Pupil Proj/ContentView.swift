import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraModel()
    @State private var selectedIndex: Int? = nil
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Camera preview with navy-gray background
                ZStack {
                    Color(red: 20/255, green: 30/255, blue: 50/255)
                        .ignoresSafeArea()
                    CameraPreview(camera: camera)
                        .frame(width: geo.size.width,
                               height: geo.size.height * 0.8)
                }
                .onAppear { camera.startSession() }
                .onDisappear { camera.stopSession() }
                
                VStack {
                    Spacer()
                    
                    // Thumbnails
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(camera.capturedImages.enumerated()), id: \.offset) { index, img in
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 90)
                                    .cornerRadius(6)
                                    .shadow(radius: 2)
                                    .onTapGesture { selectedIndex = index }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 110)
                    
                    // Shutter button
                    HStack {
                        Spacer()
                        Button(action: { camera.takeMultiplePhotos(count: 6, interval: 0.3) }) {
                            ZStack {
                                Circle()
                                    .fill(camera.isBusy ? Color.gray : Color.white)
                                    .frame(width: 60, height: 60)
                                    .shadow(radius: 4)
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 70, height: 70)
                            }
                        }
                        .disabled(camera.isBusy)
                        .offset(y: geo.safeAreaInsets.bottom - 30) // pushed further down
                        Spacer()
                    }
                    .frame(height: 100)
                }
                
                // Fullscreen swipeable gallery
                if let _ = selectedIndex {
                    GeometryReader { tabGeo in
                        ZStack {
                            // Dynamic black background
                            Color.black
                                .opacity(max(0.1, 1 - abs(dragOffset.height) / 300.0))
                                .edgesIgnoringSafeArea(.all)
                            
                            TabView(selection: $selectedIndex) {
                                ForEach(Array(camera.capturedImages.enumerated()), id: \.offset) { index, img in
                                    VStack {
                                        Spacer()
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: tabGeo.size.width)
                                        Spacer()
                                    }
                                    .tag(index)
                                    .offset(y: dragOffset.height)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if abs(value.translation.height) > abs(value.translation.width) {
                                            dragOffset = value.translation
                                        }
                                    }
                                    .onEnded { value in
                                        if abs(value.translation.height) > abs(value.translation.width),
                                           value.translation.height > 100 {
                                            selectedIndex = nil
                                        }
                                        dragOffset = .zero
                                    }
                            )
                        }
                    }
                    .edgesIgnoringSafeArea(.all)
                }
            }
        }
    }
}
