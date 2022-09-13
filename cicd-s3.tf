resource "aws_s3_bucket" "codepipeline_artificats_ram" {
  bucket = "codepipeline-artifacts-ram"
  acl = "private"
}