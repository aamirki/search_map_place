part of search_map_place;

class SearchMapPlaceWidget extends StatefulWidget {
  SearchMapPlaceWidget({
    @required this.apiKey,
    this.placeholder = 'Search',
    this.icon = Icons.search,
    this.leadingIcon,
    this.hasClearButton = true,
    this.clearIcon = Icons.clear,
    this.iconColor = Colors.blue,
    this.iconSize = 24.0,
    this.onSelected,
    this.onSearch,
    this.language = 'en',
    this.location,
    this.radius,
    this.strictBounds = false,
    this.placeType,
    this.darkMode = false,
    this.hasShadow = true,
    this.fontSize,
    this.onClear,
    this.key,
  })  : assert((location == null && radius == null) || (location != null && radius != null)),
        super(key: key);

  final Key key;

  /// API Key of the Google Maps API.
  final String apiKey;

  /// Placeholder text to show when the user has not entered any input.
  final String placeholder;

  /// The callback that is called when one Place is selected by the user.
  final void Function(Place place) onSelected;

  /// The callback that is called when the user taps on the search icon.
  final void Function(Place place) onSearch;

  /// Language used for the autocompletion.
  ///
  /// Check the full list of [supported languages](https://developers.google.com/maps/faq#languagesupport) for the Google Maps API
  final String language;

  /// The point around which you wish to retrieve place information.
  ///
  /// If this value is provided, `radius` must be provided aswell.
  final LatLng location;

  /// The distance (in meters) within which to return place results. Note that setting a radius biases results to the indicated area, but may not fully restrict results to the specified area.
  ///
  /// If this value is provided, `location` must be provided aswell.
  ///
  /// See [Location Biasing and Location Restrict](https://developers.google.com/places/web-service/autocomplete#location_biasing) in the documentation.
  final int radius;

  /// Returns only those places that are strictly within the region defined by location and radius. This is a restriction, rather than a bias, meaning that results outside this region will not be returned even if they match the user input.
  final bool strictBounds;

  /// Place type to filter the search. This is a tool that can be used if you only want to search for a specific type of location. If this no place type is provided, all types of places are searched. For more info on location types, check https://developers.google.com/places/web-service/autocomplete?#place_types
  final PlaceType placeType;

  /// The initial icon to show in the search box
  final IconData icon;

  /// If this value is defined, the icon to show at the start of the search bar
  final IconData leadingIcon;

  /// Makes available "clear textfield" button when the user is writing.
  final bool hasClearButton;

  /// The icon to show indicating the "clear textfield" button
  final IconData clearIcon;

  /// The color of the icon to show in the search box
  final Color iconColor;

  /// The size of the the initial icon, the leading icon, and the clear icon
  final double iconSize;

  /// Enables Dark Mode when set to `true`. Default value is `false`.
  final bool darkMode;

  /// Enables a shadow when set to `true`. Default value is `true`.
  final bool hasShadow;

  /// The font size of the text inputted in the search bar and placeholder
  final double fontSize;

  /// If defined, this function will be invoked upon pressing the clear button,
  /// if `hasClearButton` has been set to `true`.
  final Function onClear;

  @override
  _SearchMapPlaceWidgetState createState() => _SearchMapPlaceWidgetState();
}

class _SearchMapPlaceWidgetState extends State<SearchMapPlaceWidget> with TickerProviderStateMixin {
  TextEditingController _textEditingController = TextEditingController();
  AnimationController _animationController;
  // SearchContainer height.
  Animation _containerHeight;
  // Place options opacity.
  Animation _listOpacity;

  List<dynamic> _placePredictions = [];
  bool _isEditing = false;
  Geocoding geocode;

  String _tempInput = "";
  String _currentInput = "";

  FocusNode _fn = FocusNode();
  Function _removeFunction;

  CrossFadeState _crossFadeState;

  @override
  void initState() {
    geocode = Geocoding(apiKey: widget.apiKey, language: widget.language);
    _animationController = AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    _containerHeight = Tween<double>(begin: 55, end: 364).animate(
      CurvedAnimation(
        curve: Interval(0.0, 0.5, curve: Curves.easeInOut),
        parent: _animationController,
      ),
    );
    _listOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        curve: Interval(0.5, 1.0, curve: Curves.easeInOut),
        parent: _animationController,
      ),
    );

    _textEditingController.addListener(_autocompletePlace);
    customListener();

    if (widget.hasClearButton) {
      _removeFunction = () async {
        if (_fn.hasFocus)
          if (mounted) setState(() => _crossFadeState = CrossFadeState.showSecond);
        else
          if (mounted) setState(() => _crossFadeState = CrossFadeState.showFirst);
      };
      _fn.addListener(_removeFunction);
      _crossFadeState = CrossFadeState.showFirst;
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: MediaQuery.of(context).size.width * 0.9,
        child: _searchContainer(
          child: _searchInput(context),
        ),
      );

  /*
  WIDGETS
  */
  Widget _searchContainer({Widget child}) {
    return AnimatedBuilder(
        animation: _animationController,
        builder: (context, _) {
          return Container(
            height: _containerHeight.value,
            decoration: _containerDecoration(),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 4),
                  child: child,
                ),
                if (_placePredictions.length > 0)
                  Opacity(
                    opacity: _listOpacity.value,
                    child: Column(
                      children: <Widget>[
                        for (var prediction in _placePredictions)
                          _placeOption(Place.fromJSON(prediction, geocode)),
                      ],
                    ),
                  ),
              ],
            ),
          );
        });
  }

  Widget _searchInput(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Row(
        children: <Widget>[
          if (widget.leadingIcon != null)
            Icon(widget.leadingIcon, color: widget.iconColor, size: widget.iconSize),
          widget.leadingIcon != null ? Container(width: 15) : Container(),
          Expanded(
            child: TextField(
              decoration: _inputStyle(),
              controller: _textEditingController,
              onSubmitted: (_) => _selectPlace(),
              onEditingComplete: _selectPlace,
              autofocus: false,
              focusNode: _fn,
              style: TextStyle(
                fontSize: widget.fontSize ?? screenWidth * 0.04,
                color: widget.darkMode ? Colors.grey[100] : Colors.grey[850],
              ),
            ),
          ),
          Container(width: 15),
          if (widget.hasClearButton)
            GestureDetector(
              onTap: () {
                if (_crossFadeState == CrossFadeState.showSecond) {
                  _textEditingController.clear();
                }
                if (widget.onClear != null) {
                  widget.onClear();
                }
              },
              child: AnimatedCrossFade(
                crossFadeState: _crossFadeState,
                duration: Duration(milliseconds: 300),
                firstChild: Icon(widget.icon, color: widget.iconColor, size: widget.iconSize),
                secondChild: Icon(Icons.clear, color: widget.iconColor, size: widget.iconSize),
              ),
            ),
          if (!widget.hasClearButton) Icon(widget.icon, color: widget.iconColor, size: widget.iconSize)
        ],
      ),
    );
  }

  Widget _placeOption(Place prediction) {
    String place = prediction.description;
    final double screenWidth = MediaQuery.of(context).size.width;

    return MaterialButton(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      onPressed: () => _selectPlace(prediction: prediction),
      child: ListTile(
        title: Text(
          place.length < 45 ? "$place" : "${place.replaceRange(45, place.length, "")} ...",
          style: TextStyle(
            fontSize: widget.fontSize ?? screenWidth * 0.04,
            color: widget.darkMode ? Colors.grey[100] : Colors.grey[850],
          ),
          maxLines: 1,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 0,
        ),
      ),
    );
  }

  /*
  STYLING
  */
  InputDecoration _inputStyle() {
    return InputDecoration(
      hintText: this.widget.placeholder,
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
      hintStyle: TextStyle(
        color: widget.darkMode ? Colors.grey[100] : Colors.grey[850],
      ),
    );
  }

  BoxDecoration _containerDecoration() {
    return BoxDecoration(
      color: widget.darkMode ? Colors.grey[800] : Colors.white,
      borderRadius: BorderRadius.all(Radius.circular(6.0)),
      boxShadow: [
        widget.hasShadow
          ? BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 10)
          : BoxShadow()
      ],
    );
  }

  /*
  METHODS
  */

  /// Will be called everytime the input changes. Making callbacks to the Places
  /// Api and giving the user Place options
  void _autocompletePlace() async {
    if (_fn.hasFocus) {
      if (mounted) {
        setState(() {
          _currentInput = _textEditingController.text;
          _isEditing = true;
        });
      }

      _textEditingController.removeListener(_autocompletePlace);

      if (_currentInput.length == 0) {
        if (!_containerHeight.isDismissed) _closeSearch();
        _textEditingController.addListener(_autocompletePlace);
        return;
      }

      if (_currentInput == _tempInput) {
        final predictions = await _makeRequest(_currentInput);
        await _animationController.animateTo(0.5);
        if (mounted) setState(() => _placePredictions = predictions);
        await _animationController.forward();

        _textEditingController.addListener(_autocompletePlace);
        return;
      }

      Future.delayed(Duration(milliseconds: 500), () {
        _textEditingController.addListener(_autocompletePlace);
        if (_isEditing == true) _autocompletePlace();
      });
    }
  }

  /// API request function. Returns the Predictions
  Future<dynamic> _makeRequest(input) async {
    String url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=${widget.apiKey}&language=${widget.language}";
    if (widget.location != null && widget.radius != null) {
      url += "&location=${widget.location.latitude},${widget.location.longitude}&radius=${widget.radius}";
      if (widget.strictBounds) {
        url += "&strictbounds";
      }
      if (widget.placeType != null) {
        url += "&types=${widget.placeType.apiString}";
      }
    }

    final response = await http.get(url);
    final json = JSON.jsonDecode(response.body);

    if (json["error_message"] != null) {
      var error = json["error_message"];
      if (error == "This API project is not authorized to use this API.")
        error += " Make sure the Places API is activated on your Google Cloud Platform";
      throw Exception(error);
    } else {
      final predictions = json["predictions"];
      return predictions;
    }
  }

  /// Will be called when a user selects one of the Place options
  void _selectPlace({Place prediction}) async {
    if (prediction != null) {
      _textEditingController.value = TextEditingValue(
        text: prediction.description,
        selection: TextSelection.collapsed(
          offset: prediction.description.length,
        ),
      );
    } else {
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Makes animation
    _closeSearch();

    // Calls the `onSelected` callback
    if (prediction is Place) widget.onSelected(prediction);
  }

  /// Closes the expanded search box with predictions
  void _closeSearch() async {
    if (!_animationController.isDismissed) await _animationController.animateTo(0.5);
    _fn.unfocus();
    if (mounted) {
      setState(() {
        _placePredictions = [];
        _isEditing = false;
      });
    }
    _animationController.reverse();
    _textEditingController.addListener(_autocompletePlace);
  }

  /// Will listen for input changes every 0.5 seconds, allowing us to make API requests only when the user stops typing.
  void customListener() {
    if (mounted) {
      Future.delayed(Duration.zero, () {
        Timer.periodic(Duration(milliseconds: 500), (Timer t) {
          if (mounted) {
            setState(() => _tempInput = _textEditingController.text);
          } else {
            t.cancel();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textEditingController.dispose();
    if (widget.hasClearButton) {
      _fn.removeListener(_removeFunction);
    }
    _fn.dispose();
    super.dispose();
  }
}
