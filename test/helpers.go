package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func configEC2instance(t *testing.T) *terraform.Options {
	asgPath := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/ec2-instance")

	return terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: asgPath,
	})
}
