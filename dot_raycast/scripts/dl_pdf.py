#!/usr/bin/env python3
"""Download PDF using Playwright when curl fails."""

import argparse
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright


def download_pdf(url: str, output_path: str, timeout: int = 60000) -> bool:
    """
    Download PDF from URL using Playwright.

    Args:
        url: URL to download from
        output_path: Path where PDF should be saved
        timeout: Timeout in milliseconds (default: 60000)

    Returns:
        True if successful, False otherwise
    """
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            context = browser.new_context(accept_downloads=True)
            page = context.new_page()

            # Navigate to URL
            page.goto(url, timeout=timeout, wait_until="networkidle")

            # Check if it's a direct PDF link or a page with PDF
            content_type = page.evaluate(
                "() => document.contentType || document.querySelector('meta[http-equiv=\"Content-Type\"]')?.content"
            )

            # If the page itself is a PDF, save it
            if content_type and "pdf" in content_type.lower():
                # Get PDF content
                pdf_content = page.content()
                Path(output_path).write_bytes(pdf_content.encode())
            else:
                # Try to find and click download link, or wait for download
                with page.expect_download(timeout=timeout) as download_info:
                    # Try common download button patterns
                    download_selectors = [
                        'a[href$=".pdf"]',
                        'a:has-text("Download")',
                        'a:has-text("PDF")',
                        'button:has-text("Download")',
                        'button:has-text("PDF")',
                    ]

                    clicked = False
                    for selector in download_selectors:
                        try:
                            element = page.query_selector(selector)
                            if element:
                                element.click()
                                clicked = True
                                break
                        except Exception:
                            continue

                    if not clicked:
                        # If no download button found, try to print as PDF
                        page.pdf(path=output_path)
                        browser.close()
                        return True

                download = download_info.value
                download.save_as(output_path)

            browser.close()

            # Verify the file was created and has content
            output_file = Path(output_path)
            if output_file.exists() and output_file.stat().st_size > 0:
                return True
            else:
                return False

    except Exception as e:
        print(f"Error downloading with Playwright: {e}", file=sys.stderr)
        return False


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Download PDF using Playwright"
    )
    parser.add_argument("url", help="URL to download from")
    parser.add_argument("output", help="Output file path")
    parser.add_argument(
        "--timeout",
        type=int,
        default=60000,
        help="Timeout in milliseconds (default: 60000)",
    )

    args = parser.parse_args()

    success = download_pdf(args.url, args.output, args.timeout)

    if success:
        print(args.output)
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
