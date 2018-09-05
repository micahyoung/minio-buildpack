package supply

import (
	"io"
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

	dep := libbuildpack.Dependency{Name: "minio", Version: "develop"}
	depScript := filepath.Join(s.Stager.DepDir(), "install_minio.sh")
	if err := s.Installer.InstallDependency(dep, depScript); err != nil {
		return err
	}

	output, err := s.Command.Output(s.Stager.DepDir(), "/bin/bash", depScript, s.Stager.DepDir())
	s.Log.Info(output)
	if err != nil {
		return err
	}

	depMinio := filepath.Join(s.Stager.DepDir(), "minio")
	if err := s.Stager.AddBinDependencyLink(depMinio, "minio"); err != nil {
		return err
	}

	return nil
}
