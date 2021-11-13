import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(
        // Pass the appropriate camera to the TakePictureScreen widget.
        camera: firstCamera,
      ),
    ),
  );
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    Key? key,
    required this.camera,
  }) : super(key: key);

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late Future<void> _initializeFirebaseFuture;
  bool _isRecordingInProgress = false;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
    _initializeFirebaseFuture = Firebase.initializeApp();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a picture')),
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;
            await _initializeFirebaseFuture;

            if (_isRecordingInProgress) {
              final videoFile = await _controller.stopVideoRecording();
              final videoBytes = await videoFile.readAsBytes();

              Widget okButton = Builder(builder: (context) {
                return TextButton(
                  child: Text("OK"),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                );
              });

              AlertDialog successDialog = AlertDialog(
                content: Text("video uploaded successfully"),
                actions: [
                  okButton,
                ],
              );

              AlertDialog failureDialog = AlertDialog(
                content: Text("failed to upload video"),
                actions: [
                  okButton,
                ],
              );
              FirebaseStorage.instance
                  .ref(videoFile.name)
                  .putData(videoBytes)
                  .then(
                      (snapshot) =>
                          showDialog(
                              context: context,
                              builder: (context) => successDialog),
                      onError: (e) => showDialog(
                          context: context,
                          builder: (context) => failureDialog));
            } else {
              await _controller.startVideoRecording();
            }
            setState(() {
              _isRecordingInProgress = !_isRecordingInProgress;
            });
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
        child:
            Icon(_isRecordingInProgress ? Icons.videocam_off : Icons.videocam),
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({Key? key, required this.imagePath})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Image.file(File(imagePath)),
    );
  }
}
