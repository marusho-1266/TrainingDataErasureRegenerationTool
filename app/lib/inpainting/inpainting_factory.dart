import 'package:training_data_erasure/inpainting/inpainting_engine.dart';
import 'package:training_data_erasure/inpainting/inpainting_factory_mobile.dart'
    if (dart.library.html) 'package:training_data_erasure/inpainting/inpainting_factory_web.dart'
    as impl;

InpaintingEngine createInpaintingEngine() => impl.createInpaintingEngine();
