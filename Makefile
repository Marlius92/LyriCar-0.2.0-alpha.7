.PHONY: test validate preview project ipa ipa-standard ipa-experimental clean

test:
	swift test
	python3 -m unittest discover -s WindowsPreview/tests -v

validate:
	./scripts/validate.sh

preview:
	python3 WindowsPreview/lyricar_preview.py

project:
	./scripts/generate_project.sh

ipa: ipa-standard

ipa-standard:
	./scripts/build_unsigned_ipa.sh LyriCar LyriCar LyriCar-standard-unsigned

ipa-experimental:
	./scripts/build_unsigned_ipa.sh LyriCarExperimental LyriCarExperimental LyriCar-carplay-experimental-unsigned

clean:
	rm -rf .build build DerivedData LyriCar.xcodeproj WindowsPreview/build WindowsPreview/dist
