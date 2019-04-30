package supply

import (
	"io"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/libbuildpack"
)

type Stager interface {
	//TODO: See more options at https://github.com/cloudfoundry/libbuildpack/blob/master/stager.go
	BuildDir() string
	DepDir() string
	DepsIdx() string
	DepsDir() string
	AddBinDependencyLink(destPath, sourceName string) error
}

type Manifest interface {
	//TODO: See more options at https://github.com/cloudfoundry/libbuildpack/blob/master/manifest.go
	AllDependencyVersions(string) []string
	DefaultVersion(string) (libbuildpack.Dependency, error)
}

type Installer interface {
	//TODO: See more options at https://github.com/cloudfoundry/libbuildpack/blob/master/installer.go
	InstallDependency(libbuildpack.Dependency, string) error
	InstallOnlyVersion(string, string) error
}

type Command interface {
	//TODO: See more options at https://github.com/cloudfoundry/libbuildpack/blob/master/command.go
	Execute(string, io.Writer, io.Writer, string, ...string) error
	Output(dir string, program string, args ...string) (string, error)
}

type Supplier struct {
	Manifest  Manifest
	Installer Installer
	Stager    Stager
	Command   Command
	Log       *libbuildpack.Logger
}

func (s *Supplier) Run() error {
	s.Log.BeginStep("Supplying minio")

	minioLinuxDep := libbuildpack.Dependency{Name: "minio-linux", Version: "latest"}
	depMinioLinuxPath := filepath.Join(s.Stager.DepDir(), "minio-linux")
	if err := s.Installer.InstallDependency(minioLinuxDep, depMinioLinuxPath); err != nil {
		return err
	}

	minioWindowsDep := libbuildpack.Dependency{Name: "minio-windows", Version: "latest"}
	depMinioWindowsPath := filepath.Join(s.Stager.DepDir(), "minio-windows")
	if err := s.Installer.InstallDependency(minioWindowsDep, depMinioWindowsPath); err != nil {
		return err
	}

	mcLinuxDep := libbuildpack.Dependency{Name: "mc", Version: "latest"}
	depMc := filepath.Join(s.Stager.DepDir(), "mc")
	if err := s.Installer.InstallDependency(mcLinuxDep, depMc); err != nil {
		return err
	}

	if err := os.Chmod(depMinioLinuxPath, 0755); err != nil {
		return err
	}

	if err := os.Chmod(depMinioWindowsPath, 0755); err != nil {
		return err
	}

	if err := os.Chmod(depMc, 0755); err != nil {
		return err
	}

	if err := s.Stager.AddBinDependencyLink(depMinioLinuxPath, "minio"); err != nil {
		return err
	}

	if err := s.Stager.AddBinDependencyLink(depMinioWindowsPath, "minio.exe"); err != nil {
		return err
	}

	if err := s.Stager.AddBinDependencyLink(depMc, "mc"); err != nil {
		return err
	}

	return nil
}
