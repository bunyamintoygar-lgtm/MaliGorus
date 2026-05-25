import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_config_provider.dart';
import '../../core/utils/market_icon_helper.dart';
import '../../data/models/market_product_model.dart';
import '../../data/models/market_category_model.dart';
import '../../data/supabase/admin_market_service.dart';

class AdminMarketProductFormScreen extends ConsumerStatefulWidget {
  final MarketProductModel? product;
  final int? initialStep;

  const AdminMarketProductFormScreen({super.key, this.product, this.initialStep});

  @override
  ConsumerState<AdminMarketProductFormScreen> createState() => _AdminMarketProductFormScreenState();
}

class _AdminMarketProductFormScreenState extends ConsumerState<AdminMarketProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late int _currentStep;

  // Step 1: Temel Bilgiler
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _categoryController;
  String _selectedCategory = 'Şablonlar';
  String _selectedAltCategory = 'İş & Yönetim';
  String _selectedFormat = 'DOCX';
  String _selectedLanguage = 'Türkçe';

  // Step 2: Dosyalar & Görseller
  List<PlatformFile> _pickedFiles = [];
  List<String> _imageUrls = [];

  // Step 3: Fiyat & Ayarlar
  late final TextEditingController _costController;
  late final TextEditingController _stockController;
  late final TextEditingController _downloadLimitController;
  late bool _isActive;
  bool _refundable = true;

  // Metadata Controllers (fallback/backward-compatibility support)
  late final TextEditingController _videoUrlController;
  late final TextEditingController _featuresController;
  late final TextEditingController _docPagesController;
  late final TextEditingController _docValidityController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep ?? 0;
    final p = widget.product;

    _titleController = TextEditingController(text: p?.title);
    _descController = TextEditingController(text: p?.description);
    _categoryController = TextEditingController(text: p?.category);
    _selectedCategory = p?.category ?? 'Şablonlar';
    _selectedFormat = p?.fileType ?? p?.metadata['file_type'] ?? 'DOCX';
    _selectedLanguage = p?.metadata['language'] ?? 'Türkçe';
    _selectedAltCategory = p?.metadata['alt_category'] ?? 'İş & Yönetim';

    _costController = TextEditingController(text: p?.creditCost.toString() ?? '');
    _stockController = TextEditingController(text: p?.stock.toString() ?? '999');
    final limitRaw = p?.metadata['download_limit']?.toString() ?? 'Sınırsız';
    final limitDisplay = (limitRaw == '0' || limitRaw.isEmpty) ? 'Sınırsız' : limitRaw;
    _downloadLimitController = TextEditingController(text: limitDisplay);
    _isActive = p?.isActive ?? true;
    _refundable = p?.metadata['refundable'] != false;



    // Backward compatibility metadata fields
    _videoUrlController = TextEditingController(text: p?.metadata['video_url']?.toString() ?? '');
    final featuresList = p?.metadata['features'] as List<dynamic>?;
    _featuresController = TextEditingController(text: featuresList?.join(', ') ?? '');
    _docPagesController = TextEditingController(text: p?.metadata['pages']?.toString() ?? '1');
    _docValidityController = TextEditingController(text: p?.metadata['validity']?.toString() ?? '2026 Güncel');

    // Load mock/real files from metadata if editing
    if (p != null) {
      if (p.fileUrl != null && p.fileUrl!.isNotEmpty) {
        _pickedFiles.add(PlatformFile(
          name: p.fileUrl!.split('/').last,
          size: 1250000, // mock 1.2 MB
        ));
      }
      if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
        _imageUrls.add(p.imageUrl!);
      }
    }

    _titleController.addListener(() => setState(() {}));
    _descController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _downloadLimitController.dispose();
    _videoUrlController.dispose();
    _featuresController.dispose();
    _docPagesController.dispose();
    _docValidityController.dispose();
    super.dispose();
  }

  String _getDefaultImageForType(MarketProductType type) {
    switch (type) {
      case MarketProductType.document:
        return 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=600&q=80';
      case MarketProductType.certificate:
        return 'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=600&q=80';
      case MarketProductType.liveTraining:
        return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=600&q=80';
      case MarketProductType.event:
        return 'https://images.unsplash.com/photo-1511578314322-379afb476865?w=600&q=80';
      case MarketProductType.vipService:
        return 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&q=80';
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'xlsx', 'pdf', 'pptx', 'zip'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya seçilemedi: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          // Store picked file name/data as mock visual image
          _imageUrls.add('https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=600&q=80');
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görsel seçilemedi: $e')),
      );
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final limitText = _downloadLimitController.text.trim();
      final finalLimit = (limitText == '0' || limitText.isEmpty) ? 'Sınırsız' : limitText;

      // Build dynamic metadata
      Map<String, dynamic> metadata = {
        'language': _selectedLanguage,
        'alt_category': _selectedAltCategory,
        'download_limit': finalLimit,
        'refundable': _refundable,
        'file_type': _selectedFormat.toLowerCase(),
        'validity': _docValidityController.text.trim(),
        'pages': _docPagesController.text.trim(),
      };

      if (_videoUrlController.text.trim().isNotEmpty) {
        metadata['video_url'] = _videoUrlController.text.trim();
      }

      if (_featuresController.text.trim().isNotEmpty) {
        metadata['features'] = _featuresController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      // Convert selected category to MarketProductType matching DB schema
      MarketProductType productType = MarketProductType.document;
      if (_selectedCategory == 'Eğitimler') {
        productType = MarketProductType.liveTraining;
      } else if (_selectedCategory == 'Akademi') {
        productType = MarketProductType.certificate;
      } else if (_selectedCategory == 'Zirve') {
        productType = MarketProductType.event;
      } else if (_selectedCategory == 'Özel Hizmet') {
        productType = MarketProductType.vipService;
      }

      final String finalImageUrl = _imageUrls.isNotEmpty ? _imageUrls.first : _getDefaultImageForType(productType);
      final String finalFileUrl = _pickedFiles.isNotEmpty ? 'https://supabase.com/storage/v1/object/public/files/${_pickedFiles.first.name}' : '';

      final productData = MarketProductModel(
        id: widget.product?.id ?? '',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: finalImageUrl,
        creditCost: int.tryParse(_costController.text) ?? 0,
        stock: int.tryParse(_stockController.text) ?? 999,
        isActive: _isActive,
        type: productType,
        category: _selectedCategory,
        fileUrl: finalFileUrl,
        fileType: _selectedFormat.toLowerCase(),
        metadata: metadata,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
      );

      final productMap = productData.toJson();
      final isEditMode = widget.product != null;
      if (!isEditMode) {
        productMap.remove('id'); // Let Supabase/PostgreSQL generate UUID
        await ref.read(adminMarketServiceProvider).addProduct(MarketProductModel.fromJson(productMap));
      } else {
        await ref.read(adminMarketServiceProvider).updateProduct(widget.product!.id, productMap);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ürün başarıyla kaydedildi!'), backgroundColor: Colors.green),
        );
        context.pop(true); // Return true to refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showCategoryPicker() {
    final categoriesAsync = ref.read(marketCategoriesProvider);
    final categories = categoriesAsync.asData?.value ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kategori Seç',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...categories.map((cat) {
                      final catIcon = MarketIconHelper.get(cat.icon);
                      final catColor = MarketIconHelper.colorFromHex(cat.color);
                      return RadioListTile<String>(
                        title: Row(
                          children: [
                            Icon(catIcon, size: 20, color: catColor),
                            const SizedBox(width: 10),
                            Text(cat.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        value: cat.label,
                        groupValue: _selectedCategory,
                        activeColor: catColor,
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() => _selectedCategory = val);
                            setState(() {
                              _selectedCategory = val;
                              // Auto update subcategory on category change
                              if (cat.subcategories.isNotEmpty) {
                                _selectedAltCategory = cat.subcategories.first.label;
                              } else {
                                _selectedAltCategory = '';
                              }
                            });
                          }
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Seç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFormatPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final formats = ['DOCX', 'XLSX', 'PDF', 'PPTX', 'ZIP', 'Diğer'];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Format Seç',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...formats.map((fmt) => RadioListTile<String>(
                          title: Text(fmt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          value: fmt,
                          groupValue: _selectedFormat,
                          activeColor: const Color(0xFF4F46E5),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => _selectedFormat = val);
                              setState(() => _selectedFormat = val);
                            }
                          },
                        )),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Seç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAltCategoryPicker() {
    final categoriesAsync = ref.read(marketCategoriesProvider);
    final categories = categoriesAsync.asData?.value ?? [];
    
    // Find currently selected category model
    MarketCategoryModel? matchedCat;
    for (var c in categories) {
      if (c.label == _selectedCategory) {
        matchedCat = c;
        break;
      }
    }

    final altCategories = matchedCat?.subcategories ?? [];

    if (altCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu kategoriye ait alt kategori bulunmamaktadır.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Alt Kategori Seç',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...altCategories.map((sub) {
                      final subIcon = MarketIconHelper.get(sub.icon);
                      return RadioListTile<String>(
                        title: Row(
                          children: [
                            Icon(subIcon, size: 18, color: const Color(0xFF4F46E5)),
                            const SizedBox(width: 8),
                            Text(sub.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        value: sub.label,
                        groupValue: _selectedAltCategory,
                        activeColor: const Color(0xFF4F46E5),
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() => _selectedAltCategory = val);
                            setState(() => _selectedAltCategory = val);
                          }
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Seç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final languages = ['Türkçe', 'İngilizce', 'Almanca', 'Fransızca'];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dil Seç',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...languages.map((lang) => RadioListTile<String>(
                          title: Text(lang, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          value: lang,
                          groupValue: _selectedLanguage,
                          activeColor: const Color(0xFF4F46E5),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => _selectedLanguage = val);
                              setState(() => _selectedLanguage = val);
                            }
                          },
                        )),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Seç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIndicatorCircle(0, 'Temel Bilgiler'),
          _buildIndicatorDivider(0),
          _buildIndicatorCircle(1, 'Dosyalar'),
          _buildIndicatorDivider(1),
          _buildIndicatorCircle(2, 'Fiyat & Ayarlar'),
        ],
      ),
    );
  }

  Widget _buildIndicatorCircle(int step, String label) {
    final isCompleted = _currentStep > step;
    final isActive = _currentStep == step;

    Color color = Colors.grey[300]!;
    Widget child = Text('${step + 1}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12));

    if (isActive) {
      color = const Color(0xFF4F46E5);
      child = Text('${step + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12));
    } else if (isCompleted) {
      color = const Color(0xFF16A34A);
      child = const Icon(Icons.check, color: Colors.white, size: 14);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(child: child),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isActive
                ? const Color(0xFF4F46E5)
                : (isCompleted ? const Color(0xFF16A34A) : Colors.grey[500]),
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildIndicatorDivider(int step) {
    final isCompleted = _currentStep > step;
    return Container(
      width: 48,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
      color: isCompleted ? const Color(0xFF16A34A) : Colors.grey[200],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isEditMode = p != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          isEditMode ? 'Ürün Düzenle' : 'Yeni Ürün Ekle',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildStepIndicator(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      physics: const BouncingScrollPhysics(),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _buildCurrentStepContent(),
                        ),
                      ),
                    ),
                  ),

                  // Fixed Footer Buttons
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: SafeArea(
                      child: Row(
                        children: [
                          if (_currentStep > 0) ...[
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: () => setState(() => _currentStep--),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E293B),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Geri', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_currentStep < 2) {
                                  if (_formKey.currentState!.validate()) {
                                    setState(() => _currentStep++);
                                  }
                                } else {
                                  _saveProduct();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text(
                                _currentStep < 2 ? 'Devam Et' : 'Kaydet & Yayınla',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Content();
      case 1:
        return _buildStep2Content();
      case 2:
      default:
        return _buildStep3Content();
    }
  }

  // --- STEP 1: TEMEL BİLGİLER ---
  Widget _buildStep1Content() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Temel Bilgiler',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 20),

        // Ürün Adı
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Ürün Adı *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
            Text('${_titleController.text.length}/100', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: 'Toplantı Notu Şablonu',
            counterText: '',
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (val) => val == null || val.trim().isEmpty ? 'Ürün adı zorunludur' : null,
        ),
        const SizedBox(height: 16),

        // Kısa Açıklama
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Kısa Açıklama *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
            Text('${_descController.text.length}/160', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descController,
          maxLength: 160,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Toplantılarınızı düzenli, anlaşılır ve profesyonel şekilde kayıt altına alın.',
            counterText: '',
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: (val) => val == null || val.trim().isEmpty ? 'Açıklama zorunludur' : null,
        ),
        const SizedBox(height: 20),

        // Kategori Seçici
        const Text('Kategori *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showCategoryPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_selectedCategory, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Alt Kategori Seçici
        const Text('Alt Kategori *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showAltCategoryPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_selectedAltCategory, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Format Seçici & Dil Yan Yana
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Format *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showFormatPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selectedFormat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dil *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showLanguagePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selectedLanguage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        // Extras
        const Divider(),
        const SizedBox(height: 12),
        const Text('Diğer Detaylar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _videoUrlController,
          decoration: const InputDecoration(
            labelText: 'YouTube Video Tanıtım Linki (Opsiyonel)',
            prefixIcon: Icon(Icons.play_circle_fill, color: Colors.red),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _featuresController,
          decoration: const InputDecoration(
            labelText: 'Özellik Listesi (Virgülle Ayırın)',
            prefixIcon: Icon(Icons.list_alt_rounded),
          ),
        ),
      ],
    );
  }

  // --- STEP 2: DOSYALAR ---
  Widget _buildStep2Content() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dosyalar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        Text('Ürün dosyalarını yükleyin. (Maks. 5 dosya)', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 16),

        // List of Picked Files
        if (_pickedFiles.isNotEmpty) ...[
          ..._pickedFiles.map((file) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'W',
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _pickedFiles.remove(file);
                        });
                      },
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],

        // Upload Dotted Area
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFC7D2FE),
                style: BorderStyle.solid,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: Color(0xFF4F46E5), size: 36),
                  const SizedBox(height: 8),
                  const Text(
                    'Dosya Yükle',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'veya dosyayı buraya sürükleyin\n(DOCX, XLSX, PDF, PPTX | Max 50 MB)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Önizleme Görselleri Section
        const Text(
          'Önizleme Görselleri',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 4),
        Text('Ürün görsellerini yükleyin. (Maks. 5 görsel)', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 16),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ..._imageUrls.map((url) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _imageUrls.remove(url);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 12),
                        ),
                      ),
                    )
                  ],
                )),
            if (_imageUrls.length < 5)
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.add, color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // --- STEP 3: FİYAT & AYARLAR ---
  Widget _buildStep3Content() {
    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fiyat & Erişim',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 20),

        // Kredi Ücreti
        const Text('Kredi Ücreti *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        TextFormField(
          controller: _costController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.stars_rounded, color: AppTheme.creditGold),
            suffixText: 'Kredi',
            hintText: '450',
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) return 'Kredi maliyeti zorunludur';
            if (int.tryParse(val) == null) return 'Geçerli bir sayı giriniz';
            return null;
          },
        ),
        const SizedBox(height: 20),

        // Satış Durumu Toggle Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Satış Durumu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                SizedBox(height: 2),
                Text('Ürün markette satışa açık olsun mu?', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            Switch(
              value: _isActive,
              activeColor: const Color(0xFF4F46E5),
              onChanged: (val) => setState(() => _isActive = val),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // İndirme Limiti
        const Text('İndirme Limiti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        TextFormField(
          controller: _downloadLimitController,
          decoration: const InputDecoration(
            hintText: 'Sınırsız',
          ),
        ),
        const SizedBox(height: 20),



        // İade Edilebilir Toggle Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('İade Edilebilir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                SizedBox(height: 2),
                Text('Kullanıcılar iade talebi gönderebilsin.', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            Switch(
              value: _refundable,
              activeColor: const Color(0xFF4F46E5),
              onChanged: (val) => setState(() => _refundable = val),
            ),
          ],
        ),
      ],
    );
  }
}
