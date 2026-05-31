{
  description = "scantpaper - A GUI to produce PDFs or DjVus from scanned documents.";

  inputs = {
    nixpkgs.url = "nixpkgs";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          pyproject = lib.importTOML ./pyproject.toml;
          python = pkgs.python3;
          pythonPackages = pkgs.python3Packages;
          typelibPath = lib.makeSearchPath "lib/girepository-1.0" [
            pkgs.atk.out
            pkgs.gdk-pixbuf.out
            pkgs.glib.out
            pkgs.goocanvas_2.out
            pkgs.harfbuzz.out
            pkgs.gtk3.out
            pkgs.pango.out
          ];
          xdgDataPath = lib.makeSearchPath "share" [
            pkgs.gdk-pixbuf.out
            pkgs.gtk3.out
          ];

          scantpaper = pythonPackages.buildPythonApplication rec {
            pname = pyproject.project.name;
            version = pyproject.project.version;
            format = "pyproject";

            src = ./.;
            doCheck = false;

            nativeBuildInputs = with pythonPackages; [
              setuptools
              wheel
            ] ++ [
              pkgs.wrapGAppsHook3
              pkgs.makeWrapper
              pkgs.gettext
            ];

            buildInputs = [
              pkgs.atk
              pkgs.cairo
              pkgs.gdk-pixbuf
              pkgs.goocanvas_2
              pkgs.harfbuzz
              pkgs.gtk3
              pkgs.pango
            ];

            propagatedBuildInputs = with pythonPackages; [
              img2pdf
              ocrmypdf
              pycairo
              pygobject3
              python-iso639
              sane
              tesserocr
            ];

            postInstall = ''
              install -Dm644 org.scantpaper.desktop $out/share/applications/org.scantpaper.desktop
              install -Dm644 scantpaper.appdata.xml $out/share/metainfo/scantpaper.appdata.xml

              mkdir -p $out/share/icons
              cp -r icons/hicolor $out/share/icons/

              mkdir -p $out/share/locale
              for po_file in po/*.po; do
                lang=''${po_file##*-}
                lang=''${lang%.po}
                install -d $out/share/locale/$lang/LC_MESSAGES
                msgfmt "$po_file" -o $out/share/locale/$lang/LC_MESSAGES/scantpaper.mo
              done

              mkdir -p $out/${python.sitePackages}
              ln -sfn $out/share/icons $out/${python.sitePackages}/icons
              ln -sfn $out/share/locale $out/${python.sitePackages}/locale
            '';

            preFixup = ''
              gappsWrapperArgs+=(
                --prefix GI_TYPELIB_PATH : "${typelibPath}"
                --prefix XDG_DATA_DIRS : "${xdgDataPath}"
              )

              makeWrapperArgs+=(
                --prefix GI_TYPELIB_PATH : "${typelibPath}"
                --prefix XDG_DATA_DIRS : "${xdgDataPath}"
                --prefix PATH : ${
                  lib.makeBinPath [
                    pkgs.djvulibre
                    pkgs.imagemagick
                    pkgs.libtiff
                    pkgs.poppler-utils
                    pkgs.qpdf
                    pkgs.tesseract
                    pkgs.unpaper
                    pkgs.xdg-utils
                  ]
                }
              )
            '';

            meta = {
              description = pyproject.project.description;
              homepage = pyproject.project.urls.Homepage;
              license = lib.licenses.gpl3Only;
              mainProgram = "scantpaper";
              platforms = systems;
            };
          };
        in
        {
          default = scantpaper;
          scantpaper = scantpaper;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/scantpaper";
        };
      });
    };
}
