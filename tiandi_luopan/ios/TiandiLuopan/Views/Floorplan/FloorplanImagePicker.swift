import SwiftUI
import UIKit

// MARK: - 户型图纸相册选取器 (Floorplan Image Picker)

public struct FloorplanImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onImagePicked: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode
    
    public init(selectedImage: Binding<UIImage?>, onImagePicked: (() -> Void)? = nil) {
        self._selectedImage = selectedImage
        self.onImagePicked = onImagePicked
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    public class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: FloorplanImagePicker
        
        init(_ parent: FloorplanImagePicker) {
            self.parent = parent
        }
        
        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Floor plans from modern cameras can exceed 10,000 px and keep
                // hundreds of MB alive while the SwiftUI canvas is displayed.
                // The canvas is only a few hundred points high and is used for
                // room placement rather than pixel-level editing. Keep enough
                // detail for alignment while bounding the decoded bitmap to a
                // much smaller memory footprint.
                parent.selectedImage = Self.downsample(image, maxDimension: 2048)
                parent.onImagePicked?()
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }

        private static func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
            let pixelWidth = image.size.width * image.scale
            let pixelHeight = image.size.height * image.scale
            let longestPixelSide = max(pixelWidth, pixelHeight)
            guard longestPixelSide > maxDimension, longestPixelSide > 0 else { return image }
            let scale = maxDimension / longestPixelSide
            let targetSize = CGSize(width: max(1, pixelWidth * scale),
                                    height: max(1, pixelHeight * scale))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }
    }
}
