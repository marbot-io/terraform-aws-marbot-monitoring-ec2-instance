package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestDefault(t *testing.T) {
	t.Parallel()

	terraformPath := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/default")

	ec2Options := configEC2instance(t)

	defer terraform.Destroy(t, ec2Options)
	terraform.InitAndApply(t, ec2Options)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformPath,
		Vars: map[string]interface{}{
			"endpoint_id": os.Getenv("MARBOT_ENDPOINT_ID"),
			"instance_id": terraform.Output(t, ec2Options, "instance_id"),
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}
