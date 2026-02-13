import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  // TODO: Replace with your actual cloud name and upload preset
  final CloudinaryPublic cloudinary =
      CloudinaryPublic('dhcdhtpfj', 'portfolio_upload', cache: false);
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return null;

      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(image.path,
            resourceType: CloudinaryResourceType.Image),
      );

      return response.secureUrl;
    } catch (e) {
      if (e.toString().contains('DioException')) {
        final dynamic dioError = e;
        print("CLOUDINARY ERROR: ${dioError.message}");
        if (dioError.response != null) {
          print("Response Data: ${dioError.response?.data}");
          print("Status Code: ${dioError.response?.statusCode}");
        }
      } else {
        print("Error uploading to Cloudinary: $e");
      }
      return null;
    }
  }

  Future<String?> uploadPdf(String path) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          path,
          resourceType: CloudinaryResourceType.Auto,
          folder: 'resumes',
        ),
      );
      return response.secureUrl;
    } catch (e) {
      print("Error uploading PDF: $e");
      return null;
    }
  }
}
